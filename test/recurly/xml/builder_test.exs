defmodule Recurly.XML.BuilderTest do
  use ExUnit.Case, async: true
  alias Recurly.XML.Builder

  test "turns a changeset into xml" do
    xml_doc = canonicalize """
    <my_resource>
      <a_string>A String</a_string>
      <an_integer>123</an_integer>
      <a_float>3.14</a_float>
      <an_embedded_resource>
        <name>An Embedded Resource</name>
        <a_tripple_embedded_resource>
          <name>A Tripple Embedded Resource</name>
        </a_tripple_embedded_resource>
      </an_embedded_resource>
      <an_array type="array">
        <an_embedded_resource>
          <name>Element 1</name>
        </an_embedded_resource>
        <an_embedded_resource>
          <name>Element 2</name>
        </an_embedded_resource>
      </an_array>
    </my_resource>
    """

    changeset = [
      a_string: "A String",
      an_integer: 123,
      a_float: 3.14,
      an_embedded_resource: [
        name: "An Embedded Resource",
        a_tripple_embedded_resource: [
          name: "A Tripple Embedded Resource"
        ]
      ],
      an_array: [
        an_embedded_resource: [
          name: "Element 1"
        ],
        an_embedded_resource: [
          name: "Element 2"
        ]
      ]
    ]

    assert canonicalize(Builder.generate(changeset, MyResource)) == xml_doc
  end

  test "turns a changeset with nils into xml with nils" do
    xml_doc = canonicalize """
    <my_resource>
      <a_string>A String</a_string>
      <an_integer>123</an_integer>
      <a_float nil="nil"/>
    </my_resource>
    """

    changeset = [
      a_string: "A String",
      an_integer: 123,
      a_float: nil,
    ]

    assert canonicalize(Builder.generate(changeset, MyResource)) == xml_doc
  end

  # TODO could be smarter by removing only whitespace b/w elements
  defp canonicalize(xml_doc) do
    xml_doc
    |> String.replace("\t", "")
    |> String.replace("\n", "")
    |> String.replace(~r/\s/, "")
  end
end
