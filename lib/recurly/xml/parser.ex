defprotocol Recurly.XML.Parser do
  @moduledoc """
  Protocol responsible for parsing xml into resources
  """

  @doc """
  Parses an xml document into the given resource

  ## Parameters

  - `resource` empty resource struct to parse into
  - `xml_doc` String xml document
  - `list` boolean value, use true if top level xml is a list

  ## Examples

  ```
  xml_doc = "<account><account_code>myaccount</account></account>"
  account = Recurly.XML.Parser.parse(%Recurly.Account{}, xml_doc, false)
  ```
  """
  def parse(resource, xml_doc, list)
end

defimpl Recurly.XML.Parser, for: Any do
  import SweetXml
  alias Recurly.XML.Types
  alias Recurly.XML.Schema
  alias Recurly.XML.Field

  def parse(resource, xml_doc, true) do
    type = resource.__struct__
    path = to_char_list("//#{type.__resource_name__}")
    path = %SweetXpath{path: path, is_list: true}

    xml_doc
    |> xpath(path)
    |> Enum.map(fn xml_node ->
      parse(resource, xml_node, false)
    end)
  end
  def parse(resource, xml_doc, false) do
    type = resource.__struct__
    path = "/#{type.__resource_name__}/"

    xml_doc
    |> to_struct(type, path)
    |> insert_actions(xml_doc, path)
  end

  defp insert_actions(resource_struct, xml_doc, string_path) do
    path = %SweetXpath{path: to_char_list(string_path <> "a"), is_list: true}
    meta = resource_struct.__meta__

    actions =
      xml_doc
      |> xmap(
          actions: [
            path,
            name: ~x"./@name"s,
            href: ~x"./@href"s,
            method: ~x"./@method"s
          ]
        )
      |> Map.get(:actions)
      |> Enum.reduce(%{}, fn (action, acc) ->
        name = action |> Map.get(:name) |> String.to_atom
        method = action |> Map.get(:method) |> String.to_atom
        action = [method, Map.get(action, :href)]

        Map.put(acc, name, action)
      end)

    %{resource_struct | __meta__: Map.put(meta, :actions, actions)}
  end

  # TODO - this must be refactored
  defp to_struct(xml_node, type, string_path) do
    schema = Schema.get(type)
    href_attr = attribute(xml_node, string_path, "href")
    path = %SweetXpath{path: to_char_list(string_path <> "*"), is_list: true}

    xml_node
    |> xpath(path)
    |> Enum.map(fn xml_node ->
      attr_name = xml_node |> xpath(~x"name(.)"s) |> String.to_atom
      field = Schema.find_field(schema, attr_name)
      type_attr = attribute(xml_node, "./", "type")
      node_href_attr = attribute(xml_node, "./", "href")
      nill_attr = attribute(xml_node, "./", "nil")
      childless = xpath(xml_node, ~x"./*") == nil

      if field do
        cond do
          nill_attr == "nil" ->
            {attr_name, nil}
          childless and node_href_attr != nil ->
            {
              attr_name,
              %Recurly.Association{
                href: node_href_attr,
                resource_type: field.type,
                paginate: Field.pageable?(field)
              }
            }
          type_attr == "array" ->
            path = %SweetXpath{path: './*', is_list: true}

            resources =
              xml_node
              |> xpath(path)
              |> Enum.map(fn element_xml_node ->
                to_struct(element_xml_node, field.type, "./")
              end)

            {attr_name, resources}
          Types.primitive?(field.type) ->
            # Can be parsed and cast to a primitive type
            path = %SweetXpath{path: './text()', cast_to: field.type}
            val = xpath(xml_node, path)

            # TODO a better way to detect nil
            if val == "" do
              nil
            else
              {attr_name, val}
            end
          true ->
            # Is embedded and must parse out the children attributes
            {attr_name, to_struct(xml_node, field.type, "./")}
        end
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.concat([{:__meta__, %{href: href_attr}}])
    |> from_map(type)
  end

  defp from_map(enum, type) do
    struct(type, enum)
  end

  defp attribute(xml_node, path, attribute) do
    path = %SweetXpath{path: to_char_list("#{path}@#{attribute}"), cast_to: :string}
    value = xpath(xml_node, path)
    case value do
      "" -> nil
      _  -> value
    end
  end
end