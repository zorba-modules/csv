xquery version "3.0";

(:
 : Copyright 2006-2009 The FLWOR Foundation.
 :
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 : http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
:)

(:~
 : Function library providing converters from CSV/TXT to XML and back.
 : The functions are optimized to work with large amounts of data, in a streaming way.
 :
 : @author Daniel Turcanu
 : @project Zorba/Data Converters/CSV
 :)
module namespace csv = "http://zorba.io/modules/csv";

(:~
 : Import module for checking if csv options element is validated.
 :)
import module namespace schemaOptions = "http://zorba.io/modules/schema";

(:~
 : Contains the definitions of the csv options element.
  :)
import schema namespace csv-options = "http://zorba.io/modules/csv-options";

declare namespace ver = "http://zorba.io/options/versioning";
declare option ver:module-version "1.0";

(:~
 : Parse a CSV or fixed size text and convert to XML.<br/>
 : By default each line is converted to a &lt;row> element, and each field to a &lt;column> element inside &lt;row>.<br/>
 : The format of the param $options is:<br/>
 :  <pre>
 :    &lt;csv-options:options>
 :        &lt;csv  [separator="default comma ,"] ?
 :          [quote-char="default double quotes &amp;quote;"]?
 :          [quote-escape="default double double quotes &amp;quote;&amp;quote;"]? />
 : 
 :        or
 :        &lt;column-widths>
 :          &lt;column-width><i>[column fixed width, unsigned int]</i>&lt;column-width>*
 :        &lt;/column-widths>
 :
 :        or
 :        &lt;column-positions>
 :          &lt;column-position><i>[column position on line, unsigned int]</i>&lt;column-position>*
 :        &lt;/column-positions>
 :
 :        &lt;first-row-is-header [line="<i>first_line[-last_line]?</i>"]?/>?
 :        &lt;start-from-row line="<i>first_line[-last_line]?</i>"/>?
 :        &lt;add-last-void-columns/>?
 :        &lt;xml-nodes>
 :          [&lt;<i>row-name</i>>
 :            [&lt;<i>column-name/</i>>]?
 :          &lt;/<i>row-name</i>>]?
 :        &lt;/xml-nodes>?
 :    &lt;/csv-options:options>
 :  </pre>
 :    All the parameters are optional and can appear in any order.<br/>
 :    All the parameters are case sensitive. The namespace used is "http://zorba.io/modules/csv-options".<br/>
 :    All strings must have UTF-8 encoding.<br/>
 :    Parameters csv, column-widths, column-positions are mutually exclusive. If none is specified, 
 :    the input string is assumed to be csv.<br/>
 :    Description of parameters:
 :    <dl>
 :     <dt><b>csv</b></dt>
 :     <dd> Specifies the parameters for parsing a csv string.<br/>
 :       <dl> 
 :        <dt><b>separator</b></dt>
 :        <dd>The character or group of characters used to separating fields in a row. 
 :            If it is not specified, it defaults to comma ','.
 :        </dd>
 :        <dt><b>quote-char</b></dt>
 :        <dd>The character or group of characters used for quoting the fields that may contain special characters,
 :             like separator, new line or this quote char. The default value is double quote ".<br/>
 :        </dd>
 :        <dt><b>quote-escape</b></dt>
 :        <dd>The group of characters used for escaping the quote char inside a field. The whole quote escape group
 :           is translated to a quote char during parsing. The default value is double double quotes "".<br/>
 :        </dd>
 :       </dl>
 :     </dd>
 :     <br/>
 :     <dt><b>column-widths</b></dt>
 :     <dd>Specifies the column widths for fixed size text. It contains multiple column-width child elements
 :        specifying the fixed width of each column, from left to right.<br/>
 :        If the line has more fields than specified, they are ignored. 
 :     </dd>
 :     <dt><b>column-positions</b></dt>
 :     <dd>This is an alternative to column-widths, and specifies instead the starting position of each column.
 :        Column positions are 1 based, and are specified in order from left to right. 
 :        The last column is read until end of line. The first column position can be greater than 1, if you want
 :        to parse only a part of the input text.
 :     </dd>
 :     <dt><b>first-row-is-header</b></dt>
 :     <dd>The presence of this element indicates that the first row is to be treated as the name of the columns.
 :        If it is not present, then each field is enclosed in a &lt;column> element, 
 :        or how it is specified in &lt;xml-nodes> parameter.<br/>
 :        If the first row is the header, then each field is enclosed in an element with the corresponding name from the header.<br/>
 :        For example, the csv:
 :        <pre>
 :        <i>ID,Name,Occupation
 :        1,John,student</i>
 :        </pre>
 :        is parsed into:
 :        <pre>
 :        <i>&lt;row>
 :        &lt;ID>1&lt;/ID>
 :        &lt;Name>John&lt;/Name>
 :        &lt;Occupation>student&lt;/Occupation>
 :        &lt;/row></i>
 :        </pre>
 :        If the header names contain characters that cannot be used in a QName, they are replaced with underscore '_'.<br/>
 :        The namespace for the header QNames is taken from the column name specified in xml-nodes parameter, or from
 :        the row name, or if that doesn't exist either then empty namespace is used. <br/>
 :        If the header is not the first line in the input string, the starting line can be specified in the <b>line</b> attribute.<br/>
 :        If a column does not have a name, a new name is constructed in the form <i>columnN</i> where N is the position of the column,
 :        starting from 1.<br/>
 :        <b>Subheaders</b><br/>
 :        If the header consists of more than one line, this can be specified in the <b>line</b> attribute in the form
 :        "<i>first_line - last_line</i>". Having more lines as the header translates into a hierarchy of elements in the xml.<br/>
 :        For example, the csv:
 :        <pre>
 :        <i>ID,Name,,Occupation
 :        ,First Name,Last Name,
 :        1,John,Howard,student</i>
 :        </pre>
 :        is parsed into:
 :        <pre>
 :        <i>&lt;row>
 :        &lt;ID>1&lt;/ID>
 :        &lt;Name>
 :          &lt;First_Name>John&lt;/First_Name>
 :          &lt;Last_Name>Howard&lt;/Last_Name>
 :        &lt;/Name>
 :        &lt;Occupation>student&lt;/Occupation>
 :        &lt;/row></i>
 :        </pre>
 :        This element can have an attribute "accept-all-lines" with values "false" or "true" (default "false").
 :        When set to true it tells the parser to not report lines that do not have the same number of items as 
 :        the header. If set to false, the parser will raise a csv:WrongInput error for these lines.<br/>
 :     </dd>
 :     <dt><b>start-from-row</b></dt>
 :     <dd>If the data does not start from line 1 or immediately after the header, 
 :        you can specify the starting line in the <b>line</b> attribute.<br/>
 :        Also you can use this attribute in the form "<i>first_line - last_line</i>" to specify also the last line
 :        if you don't want the whole csv to be parsed.
 :     </dd>
 :     <dt><b>add-last-void-columns</b></dt>
 :     <dd>In the case when using headers and some data lines are shorter than the header, by default the excess columns are ignored
 :          for those lines. You can set the add-last-void-columns parameter to make all the columns appear in xml even if they are void.
 :     </dd>
 :     <dt><b>xml-nodes</b></dt>
 :     <dd>With this parameter you can specify the names for the row element and for the column element if there is no header.<br/>
 :        The first element child of this element specifies the desired QName of the row element in the output xml. 
 :        The name of this element will be used as the name of the row element.<br/>
 :        The element child of this row element is the column element, and its name will be used as the name of the column elements
 :        that enclose the fields in the output xml if there is no header. <br/>
 :        If the csv has a header, only the namespace is used from the column element.<br/>
 :        For example, with parameter:
 :        <pre>
 :        <i>&lt;xml-nodes>
 :        &lt;r>
 :          &lt;c/>
 :        &lt;/r>
 :        &lt;/xml-nodes></i>
 :        </pre>
 :        the output for each line will look like:
 :        <pre>
 :        <i>&lt;r>
 :          &lt;c>field1&lt;/c>
 :          &lt;c>field2&lt;/c>
 :          .......
 :        &lt;/r></i>
 :        </pre>
 :     </dd>
 :    </dl>
 : @param $csv the string containing the csv or fixed size text.
 : @param $options this parameter is validated against "http://zorba.io/modules/csv-options" schema. 
 :    If this parameter is not specified, the row name is by default "row" and the column name is by default "column". 
 : @return a sequence of row elements, one for each line in csv
 : @error csv:CSV001 if the input string is streamable string and cannot be rewinded
 : @error csv:WrongInput if the input string has lines with variable number of items, and the csv has headers and
 :         the options do not specify the ignore-foreign-input attribute
 : @error err:XQDY0027 if $options can not be validated against the csv-options schema
 : @error err:XQDY0084 if the options parameter doesn't have the name "csv-options:options".
 : @example test/Queries/converters/csv/csv_parse1.xq
 : @example test/Queries/converters/csv/csv_parse2.xq
 : @example test/Queries/converters/csv/csv_parse3.xq
 : @example test/Queries/converters/csv/csv_parse6.xq
 : @example test/Queries/converters/csv/csv_parse11.xq
 : @example test/Queries/converters/csv/csv_parse_utf8_11.xq
 : @example test/Queries/converters/csv/txt_parse5.xq
 : @example test/Queries/converters/csv/txt_parse8.xq
:)
declare function csv:parse($csv as xs:string,
                           $options as element(csv-options:options)?) as element()*
{
  let $validated-options :=
  if(empty($options)) then
    $options
  else
  if(schemaOptions:is-validated($options)) then
    $options
  else
    validate{$options}
  return
    csv:parse-internal($csv, $validated-options)
};
                                 
declare %private function csv:parse-internal($csv as xs:string,
                                 $options as element(csv-options:options, csv-options:optionsType)?) as element()* external;
                                 
(:~
 : Convert XML into CSV or fixed size text.
 :
 : Note: if you want to serialize out the result, make sure that the serializer method is set to "text". 
 : For example, in zorba command line, you have to set the param --serialize-text.
 : When using the <pre>file:write(...)</pre> function, you have to set the
 : method serialization parameter to "text":
 : <pre>
 : &lt;output:serialization-parameters&lt;
 :   &lt;output:method value="text"/&lt;
 : &lt;/output:serialization-parameters&lt;
 : </pre>
 :
 : The <pre>$options</pre> parameter must have the following format:
 : <pre>
 :    &lt;csv-options:options><br/>
 :        &lt;csv  [separator="default comma ,"] ? <br/>
 :          [quote-char="default double quotes &amp;quote;"]? <br/>
 :          [quote-escape="default double double quotes &amp;quote;&amp;quote;"]? /> <br/>
 :        <br/>
 :        or<br/>
 :        &lt;column-widths [align="left|right"]?><br/>
 :          &lt;column-width [align="left|right"]?><i>[column fixed width, unsigned int]</i>&lt;column-width>*<br/>
 :        &lt;/column-widths><br/>
 :        <br/>
 :        or<br/>
 :        &lt;column-positions [align="left|right"]?><br/>
 :          &lt;column-position [align="left|right"]?><i>[column position on line, unsigned int]</i>&lt;column-position>*<br/>
 :        &lt;/column-positions><br/>
 :        <br/>
 :        &lt;first-row-is-header/>?<br/>
 :    &lt;/csv-options:options>
 : </pre>
 :
 : All the parameters are optional and can appear in any order.<br/>
 : All the parameters are case sensitive. The namespace used is "http://zorba.io/modules/csv-options".<br/>
 : All strings must have UTF-8 encoding.<br/>
 : Parameters csv, column-widths, column-positions are mutually exclusive.
 : If none is specified, the xml is converted to csv.
 :
 : Description of parameters:
 :    <dl>
 :     <dt><b>csv</b></dt>
 :     <dd> Specifies the parameters for converting to csv.<br/>
 :       <dl> 
 :        <dt><b>separator</b></dt>
 :        <dd>The character or group of characters used to separating fields in a row. 
 :            If it is not specified, it defaults to comma ','.
 :        </dd>
 :        <dt><b>quote-char</b></dt>
 :        <dd>The character or group of characters used for quoting the fields that may contain special characters,
 :             like separator, new line or this quote char. The default value is double quote ".<br/>
 :        </dd>
 :        <dt><b>quote-escape</b></dt>
 :        <dd>The group of characters used for escaping the quote char inside a field. The whole quote escape group
 :           is translated to a quote char during parsing. The default value is double double quotes "".<br/>
 :        </dd>
 :       </dl>
 :     </dd>
 :     <br/>
 :     <dt><b>column-widths</b></dt>
 :     <dd>Specifies the column widths for fixed size text. It contains multiple column-width child elements
 :        specifying the fixed width of each column, from left to right.<br/>
 :        With the attribute <b>align</b> you can specify how to align fields that are smaller than the column width.
 :        The default alignment is left.<br/>
 :     </dd>
 :     <dt><b>column-positions</b></dt>
 :     <dd>This is an alternative to column-widths, and specifies instead the starting position of each column.
 :        Column positions are 1 based, and are specified in order from left to right. 
 :        The last column has a variable length.<br/>
 :        With the attribute <b>align</b> you can specify how to align fields that are smaller than the column width.
 :        The default alignment is left. The last column does not need alignment.<br/>
 :     </dd>
 :     <dt><b>first-row-is-header</b></dt>
 :     <dd>The presence of this element indicates that the first row will contain the header, that is, the names of
 :        the column elements. Only the column names from the first row element are taken into account.<br/>
 :        For example, the row xml:<br/>
 :        <i>&lt;row><br/>
 :        &lt;ID>1&lt;/ID><br/>
 :        &lt;Name>John&lt;/Name><br/>
 :        &lt;Occupation>student&lt;/Occupation><br/>
 :        &lt;/row></i><br/>
 :        <br/>
 :        is converted to<br/>
 :        <i>ID,Name,Occupation<br/>
 :        1,John,student</i><br/>
 :        <br/>
 :        The header names are the localnames of the column elements, and the namespace is ignored.<br/>
 :        <b>Subheaders</b><br/>
 :        If the row-column hierarchy is more complex, then subheaders are also generated on subsequent lines.
 :        The number of subheaders depends on the depth of the column hierarchy.<br/>
 :        When generating the subheaders, the non-whitespace text nodes are also taken into account, 
 :        and a separate column is generated for them too.<br/>
 :        For example, the xml row element:<br/>
 :        <i>&lt;row><br/>
 :        &lt;ID>1&lt;/ID><br/>
 :        &lt;Name><br/>
 :          Mr.<br/>
 :          &lt;First_Name>John&lt;/First_Name><br/>
 :          &lt;Last_Name>Howard&lt;/Last_Name><br/>
 :        &lt;/Name><br/>
 :        &lt;Occupation>student&lt;/Occupation><br/>
 :        &lt;/row></i><br/>
 :        is converted to<br/>
 :        <i>ID,Name,,Occupation<br/>
 :        ,,First Name,Last Name,<br/>
 :        1,Mr.,John,Howard,student</i><br/>
 :        <br/>
 :        If first-row-is-header is not specified and the columns have a deeper hierarchy,
 :          only the first layer of columns is processed, and the fields are the string values of each column.<br/>
 :        This element can have an attribute "ignore-foreign-input" with values "false" or "true" (default "false").
 :        When set to true it tells the serializer to ignore elements that to not match the header names.
 :        If set to false, the serializer will raise a csv:ForeignInput error for these elements.<br/>
 :     </dd>
 :    </dl>
 :
 : @param $xml a sequence of elements, each element representing a row. The name of each row element is ignored.
 :     The childs of each row are the column fields.
 : @param $options The options parameter. See the function description for details. 
 : This parameter is validated against "http://zorba.io/modules/csv-options" schema.
 : @return the csv or fixed size text as string containing all the lines
 : @error csv:CSV003 if the serialize output is streamable string and cannot be reset
 : @error csv:ForeignInput if there are input elements in subsequent rows that do not match the headers,
 :    and the options specify first-row-is-header and do not specify the ignore-foreign-input attribute
 : @error err:XQDY0027 if $options can not be validated against csv-options schema
 : @error err:XQDY0084 if the options parameter doesn't have the name "csv-options:options".
 : @example test/Queries/converters/csv/csv_serialize1.xq
 : @example test/Queries/converters/csv/csv_serialize2.xq
 : @example test/Queries/converters/csv/csv_serialize3.xq
 : @example test/Queries/converters/csv/csv_serialize5.xq
 : @example test/Queries/converters/csv/csv_serialize6.xq
 : @example test/Queries/converters/csv/csv_parse_serialize6.xq
 : @example test/Queries/converters/csv/txt_serialize6.xq
 : @example test/Queries/converters/csv/txt_parse_serialize6.xq
:)
declare function csv:serialize($xml as element()*,
                               $options as element(csv-options:options)?) as xs:string
{
  let $validated-options :=
  if(empty($options)) then
    $options
  else
  if(schemaOptions:is-validated($options)) then
    $options
  else
    validate{$options}
  return
    csv:serialize-internal($xml, $validated-options)
};
                                    
declare %private function csv:serialize-internal($xml as element()*,
                  $options as element(csv-options:options, csv-options:optionsType)?) as xs:string external;

(: vim:set et sw=2 ts=2: :)
