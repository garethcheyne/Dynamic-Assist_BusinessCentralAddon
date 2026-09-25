/// <summary>How a query reached the companion.</summary>
enum 77500 "DA Query Channel"
{
    Extensible = false;

    value(0; "Query Builder")
    {
        Caption = 'Query builder';
    }
    value(1; "REST GET")
    {
        Caption = 'REST GET';
    }
    value(2; "REST POST")
    {
        Caption = 'REST POST';
    }
}
