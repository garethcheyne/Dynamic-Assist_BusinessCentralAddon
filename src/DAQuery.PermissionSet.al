/// <summary>
/// Lets a user use Dynamic Assist Query: the query builder and the REST
/// endpoints. Every request checks for it (read on DA Query Access), so
/// without it nothing runs. It grants no access to business data: queries
/// read with the user's own permissions.
/// </summary>
permissionset 77500 "DA QUERY"
{
    Caption = 'Dynamic Assist Query';
    Assignable = true;
    Permissions =
        tabledata "DA Query Access" = R,
        codeunit "DA Query Service" = X,
        codeunit "DA Query Join" = X,
        codeunit "DA Query API" = X,
        page "DA Query" = X,
        page "DA Query Rows API" = X,
        table "DA Query Row" = X,
        codeunit "DA Query Log Writer" = X,
        tabledata "DA Query Log" = I,
        tabledata "Table Metadata" = R,
        tabledata Field = R,
        tabledata Company = R,
        tabledata "Page Metadata" = R,
        tabledata "Page Control Field" = R,
        tabledata "Tenant Web Service" = R;
}
