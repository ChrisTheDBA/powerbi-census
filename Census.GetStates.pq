let Census.GetStates = (optional includeTerritories as logical) as table =>
    let 
        //includeTerritories = true,
        States = 
        let
            resource = Web.Page(Web.Contents("https://www.census.gov/library/reference/code-lists/ansi/ansi-codes-for-states.html")),
            ExtractedTable = resource{0}[Data]
        in
            ExtractedTable,
        Territories = 
        let
            resource = Web.Page(Web.Contents("https://www.census.gov/library/reference/code-lists/ansi/ansi-codes-for-states.html")),
            ExtractedTable = resource{1}[Data]
        in
            ExtractedTable,
        UnionStatesTemp = if not includeTerritories or includeTerritories = null then States else Table.Combine({States, Territories}),
        FixNames = Table.ReplaceValue(UnionStatesTemp,each [Name], each if [Name]=null then [Area Name] else [Name] , Replacer.ReplaceValue,{"Name"}),
        UnionStates2 = Table.RenameColumns(FixNames, {"Name", "state_name"}),
        UnionStates1 = Table.RenameColumns(UnionStates2, {"FIPS State Numeric Code", "state_fips"}),
        UnionStates = Table.RenameColumns(UnionStates1, {"Official USPS Code", "state_abbr"}),
        #"Removed Other Columns" = Table.SelectColumns(UnionStates,{"state_name", "state_fips", "state_abbr"})
in
    #"Removed Other Columns",
    ParameterTypes = type function(
        optional includeTerritories as (
            type logical meta [ 
                Documentation.AllowedValues = {true, false}
            ]
        )
    ) as table meta            
    [
        Documentation.Name =  " Census.GetStates",
        Documentation.Description = " Return a table of United States states along with FIPS codes.",
        Documentation.LongDescription = " Return a table of United States states. If the optional parameter includeTerritories is set to TRUE, the returned table will also include information on Outlying Areas of the United States and the Freely Associated States.",
        Documentation.Category = " Table.Transform",
        Documentation.Source = " ",
        Documentation.Author = " Chris Mathews",
        Documentation.Examples = {
            [
                Description =  "Return a table of United States states, including Puerto Rico and other U.S. territories.", 
                Code = " GetStates(true)", 
                Result = " Table.FromRecords({[state_name = ""Alabama"", states_fips = ""01"", state_abbr = ""AL""],[state_name = ""Alaska"", states_fips = ""02"", state_abbr = ""AK""],...,[state_name = ""U.S. Virgin Islands"", states_fips = ""78"", state_abbr = ""VI""]})"
            ]
        }
    ]  
in 
    Value.ReplaceType(Census.GetStates, ParameterTypes)