(: json:serialize called with wrong parameter: comment node:)

import module namespace json = "http://www.zorba-xquery.com/modules/converters/json";
import schema namespace html-options="http://www.zorba-xquery.com/modules/converters/json-options";

json:serialize((<!--comment-->),<options xmlns="http://www.zorba-xquery.com/modules/converters/json-options" >
              <json-param name="mapping" value="simple-json" type="array"/>
            </options>)
