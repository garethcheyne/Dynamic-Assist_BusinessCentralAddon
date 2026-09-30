/// <summary>
/// Everything in DA QUERY, plus reading and clearing the query log (who
/// queried what, through the query builder or the REST endpoints).
/// </summary>
permissionset 77501 "DA QUERY ADMIN"
{
    Caption = 'Dynamic Assist Query Admin';
    Assignable = true;
    IncludedPermissionSets = "DA QUERY";
    Permissions =
        tabledata "DA Query Log" = RD,
        page "DA Query Log" = X;
}
