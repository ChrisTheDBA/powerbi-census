let
/* Helper functions */
    combineValues = (columnName as text)=>
        let
            functionValue = {columnName,(r)=> if r is null then null else Text.Combine(List.Transform(r, Text.From), ";"), type text}
        in
            functionValue,

/* Parameters */
    vintage = Text.From("2016"),
    dataset = "acs/acs5",
    columns = {"B22007_001E"},
    geography = "tract",
    state = "37",
    county = "183",
    key = "986e2c9f64e5195d130af103f32f89d8e55cb625",

/* Variables */
    variables.url = "https://api.census.gov/data/" & vintage & "/" & dataset & "/variables.html",
    variables.response = Web.Contents(variables.url),
    variables.responseMetadata = Value.Metadata(variables.response),
    variables.responseCode = variables.responseMetadata[Response.Status],
    variables.responseHeaders = variables.responseMetadata[Headers],
    variables.records = Web.Page(variables.response),
    variables.table = variables.records{0}[Data],

// find variables
    variables.doExist = List.ContainsAll(variables.table[Name], columns),
    
    // get variable labels
    // create list of lists of variables/labels combinations
    variables.labels = 
        let
            SelectedColumns = Table.SelectColumns(variables.table,{"Name", "Title"}),
            fieldValues = Table.AddColumn(SelectedColumns, "Custom", each Record.FieldValues(_)),
            columnlabels = Table.RemoveColumns(fieldValues,{"Name", "Title"})[Custom]
        in
            columnlabels,
    // get variable data types
    // create list of lists of variables/data types combinations
    variables.dataTypes = 
        let
            SelectedColumns = Table.SelectColumns(variables.table,{"Name", "Values"}),
            ReplacedIntType = Table.ReplaceValue(SelectedColumns,"int","number",Replacer.ReplaceText,{"Values"}),
            ReplacedStringType = Table.ReplaceValue(ReplacedIntType,"string","text",Replacer.ReplaceText,{"Values"}),
            SetTypes = Table.TransformColumns(ReplacedStringType, {{"Values", each "type " & _}}),
            TextToType = Table.TransformColumns(SetTypes,{{"Values", Expression.Evaluate}}),
            fieldValues = Table.AddColumn(TextToType, "Custom", each Record.FieldValues(_)),
            columnTypes = Table.RemoveColumns(fieldValues,{"Name", "Values"})[Custom]
        in
            columnTypes,
    
/* Geographies */
    geographies.url = "https://api.census.gov/data/" & vintage & "/" & dataset & "/geography.json",
    geographies.response = Web.Contents(geographies.url),
    geographies.responseMetadata = Value.Metadata(geographies.response),
    geographies.responseCode = geographies.responseMetadata[Response.Status],
    geographies.responseHeaders = geographies.responseMetadata[Headers],
    geographies.json = Json.Document(geographies.response),
    geographies.list = geographies.json[fips],
    geographies.records = Table.FromList(geographies.list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    geographies.table = Table.ExpandRecordColumn(geographies.records, "Column1", {"name", "geoLevelId", "referenceDate", "requires", "wildcard", "optionalWithWCFor"}),
    geographies.requires = Table.TransformColumns(geographies.table,combineValues("requires")),
    geographies.wildcard = Table.TransformColumns(geographies.requires,combineValues("wildcard")),
    
/* Response */
   //data.url = "https://api.census.gov/data/" & vintage & "/" & dataset & "?get=" & Text.Combine(columns, ",") & "&for=" & geography & "&in=state:" & state & " county:" & county & "&key=" & key,
    data.url = 
        if geography = "tract" then
            "https://api.census.gov/data/" & vintage & "/" & dataset & "?get=" & Text.Combine(columns, ",") & "&for=" & geography & "&in=state:" & state & " county:" & county & "&key=" & key,
        else
            "https://api.census.gov/data/" & vintage & "/" & dataset & "?get=" & Text.Combine(columns, ",") & "&for=" & geography & "&key=" & key,
    data.response = Web.Contents(data.url),
    data.responseMetadata = Value.Metadata(data.response),
    data.responseCode = data.responseMetadata[Response.Status],
    data.responseHeaders = data.responseMetadata[Headers],
    data.json = Json.Document(data.response),
    #"Converted to Table" = Table.FromList(data.json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ParsedLists = Table.TransformColumns(#"Converted to Table", {"Column1", each Text.Combine(List.Transform(_, Text.From), ";"), type text}),
    SplitListValues = Table.SplitColumn(ParsedLists, "Column1", Splitter.SplitTextByDelimiter(";", QuoteStyle.Csv)),
    PromotedHeaders = Table.PromoteHeaders(SplitListValues, [PromoteAllScalars=true]),
    #"Duplicated Column" = Table.DuplicateColumn(PromotedHeaders, "state", "state - Copy"),
    #"Duplicated Column1" = Table.DuplicateColumn(#"Duplicated Column", "county", "county - Copy"),
    #"Duplicated Column2" = Table.DuplicateColumn(#"Duplicated Column1", "tract", "tract - Copy"),
    #"Merged Columns" = Table.CombineColumns(#"Duplicated Column2",{"state - Copy", "county - Copy", "tract - Copy"},Combiner.CombineTextByDelimiter("", QuoteStyle.None),"GEOID"),
    #"Changed Type" = Table.TransformColumnTypes(#"Merged Columns",{{"B22007_001E", Int64.Type}}),
    #"Unpivoted Other Columns" = Table.UnpivotOtherColumns(#"Changed Type", {"state", "county", "tract", "GEOID"}, "Attribute", "Value")
in
    #"Unpivoted Other Columns"