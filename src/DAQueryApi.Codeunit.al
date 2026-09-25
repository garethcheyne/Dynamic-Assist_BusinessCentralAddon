/// <summary>
/// The query builder's engine for other services, so they can query any table
/// the caller may read, like FetchXML in Dataverse. Two ways in:
///
///   POST https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/ODataV4/DAQuery_Run?company={company}
///   { "request": "{\"table\": \"Customer\", \"fields\": [\"No.\", \"Name\"]}" }
///   (the answer's "value" is the result as JSON text)
///
///   GET  .../api/err403/dynamicAssist/v1.0/companies({id})/queryRows?$filter=request eq '{...}'
///   (page "DA Query Rows API": one entity per row)
///
/// Both are off until an admin publishes this codeunit on the Web Services
/// page (Object Type Codeunit, Object ID 77502, Service Name DAQuery).
///
/// A call returns one page: 1000 rows unless "top" asks for fewer or more (at
/// most 5000). When more match, the answer has "more": true and "next"; send
/// the same request with "after": next for the following page.
///
/// Read-only and as the caller: their permissions and security filters apply.
/// Tables and fields go by name or number; a wrong one is an error saying so.
/// </summary>
codeunit 77502 "DA Query API"
{
    var
        NotJsonErr: Label 'The request isn''t valid JSON.';
        ErrorTextTok: Label '%1', Locked = true;
        RestPageSize: Integer;
        RestMaxPageSize: Integer;
        RestOffErr: Label 'Querying Business Central through Dynamic Assist is turned off. An admin can turn it on by publishing codeunit 77502 (DA Query API) on the Web Services page.';

    /// <summary>
    /// Runs a request: { method?: "query" (default) | "tables" | "fields" |
    /// "apis" | "info", table, fields, filters, sort, descending, top, count,
    /// joins, shape?: "objects" (default here) | "arrays" }.
    /// </summary>
    procedure Run(request: Text): Text
    begin
        // Reached as a web service, so it's published: no need to check
        exit(Execute(request, false, "DA Query Channel"::"REST POST"));
    end;

    /// <summary>
    /// Runs a request and logs it (who, what, how long, how it went).
    /// CheckEnabled first makes sure an admin allowed REST access.
    /// </summary>
    internal procedure Execute(RequestText: Text; CheckEnabled: Boolean; Channel: Enum "DA Query Channel"): Text
    var
        Service: Codeunit "DA Query Service";
        LogWriter: Codeunit "DA Query Log Writer";
        Json: JsonObject;
        Method: Text;
        Payload: Text;
        ResultText: Text;
        ErrorText: Text;
        Started: DateTime;
        Ok: Boolean;
        Top: Integer;
    begin
        if CheckEnabled and not IsEnabled() then
            Error(RestOffErr);
        RestPageSize := 1000;
        RestMaxPageSize := 5000;
        Started := CurrentDateTime();
        if not Json.ReadFrom(RequestText) then
            Error(NotJsonErr);
        Method := Service.GetText(Json, 'method');
        if Method = '' then
            Method := 'query';
        if Method = 'query' then begin
            if not Json.Contains('shape') then
                Json.Add('shape', 'objects');
            // One page per call: 1000 rows unless asked, 5000 at most. When more
            // match, the answer has "more": true and a "next" cursor to send
            // back as "after".
            Top := Service.GetInt(Json, 'top', RestPageSize);
            if (Top <= 0) or (Top > RestMaxPageSize) then
                Top := RestMaxPageSize;
            if Json.Contains('top') then
                Json.Replace('top', Top)
            else
                Json.Add('top', Top);
        end;
        Json.WriteTo(Payload);

        // Run guarded, so a failed query is logged too
        Service.SetRequest(Method, Payload);
        Ok := Service.Run();
        if Ok then
            ResultText := Service.GetResult()
        else
            ErrorText := GetLastErrorText();
        LogWriter.Prepare(Channel, Method, RequestText, Service.GetLastTableNo(), Service.GetLastRowCount(), CurrentDateTime() - Started, Ok, ErrorText);
        if LogWriter.Run() then;
        if not Ok then begin
            Commit();
            Error(ErrorTextTok, ErrorText);
        end;
        exit(ResultText);
    end;

    /// <summary>REST access is on when an admin has published this codeunit as a web service.</summary>
    internal procedure IsEnabled(): Boolean
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        TenantWebService.SetRange("Object Type", TenantWebService."Object Type"::Codeunit);
        TenantWebService.SetRange("Object ID", Codeunit::"DA Query API");
        TenantWebService.SetRange(Published, true);
        exit(not TenantWebService.IsEmpty());
    end;
}
