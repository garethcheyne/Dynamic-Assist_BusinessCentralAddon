# Dynamic Assist Companion (Business Central)

The Business Central app that goes with the [Dynamic Assist](https://github.com/garethcheyne/Dynamic-Assist) browser extension (Chrome and Edge). The app's source is in [DynamicAssistCompanion](DynamicAssistCompanion).

A small Business Central extension that lets the Dynamic Assist browser extension's query builder read any table, the way it does in Dynamics 365.

Business Central has no API for reading an arbitrary table: the standard APIs only cover API pages and queries. This app adds one page, **Dynamic Assist Query**, that answers the query builder from inside your own web client session.

## What it does and doesn't do

- **Read-only.** It lists tables and fields, then reads records. It never changes your data; the only thing it writes is its own query log.
- **Your permissions.** Reads go through `RecordRef` as you. A table you can't read gives an error, and security filters are applied: you only get the rows you're allowed to see.
- **Endpoints are opt-in or read-only.** The query builder only answers the browser tab that has the page open, from Business Central's own origin. The REST endpoints below are read-only, run as the caller, and need the DA QUERY permission set; the query web service is also off until an admin publishes it.

| Object | ID | What it is |
| --- | --- | --- |
| Codeunit `DA Query Service` | 77500 | Lists tables, fields and installed API pages, and runs queries (filters, sort, row limit, FlowFields, joins) |
| Codeunit `DA Query Join` | 77501 | One join: looks up the related record through a lookup field |
| Codeunit `DA Query API` | 77502 | The same engine as a web service, for other services (opt-in, see below) |
| Page `DA Query Rows API` | 77501 | The same over GET: `…/api/err403/dynamicAssist/v1.0/…/queryRows` |
| Page `DA Coupling API` | 77503 | Dataverse couplings (CRM Integration Record) over GET: `…/api/err403/dynamicassist/v1.0/…/couplings` |
| Table `DA Query Row` | 77500 | Temporary: the GET endpoint's result rows, never stored |
| Table `DA Query Log`, page `DA Query Log` | 77501, 77502 | Who queried what, when, how long, how many rows, and any error |
| Codeunit `DA Query Log Writer` | 77503 | Writes a log entry without ever breaking the query |
| Enum `DA Query Channel` | 77500 | Query builder, REST GET or REST POST |
| Permission set `DA QUERY ADMIN` | 77501 | DA QUERY plus reading and clearing the query log |
| Page `DA Query` | 77500 | "Dynamic Assist Query": hosts the bridge |
| Control add-in `DA Bridge` | | Passes messages between the extension and AL |
| Permission set `DA QUERY` | 77500 | Lets a user open the page. It grants no business data |

Publisher `ERR403`, ID range 77500–77509, platform 25.0 and later (BC 2024 wave 2+). It depends on the Base Application (25.0 or later), for the couplings endpoint's integration tables.

## Permissions

| Permission set | What it allows |
| --- | --- |
| `DA QUERY` | Querying at all, from the query builder or the REST endpoints. **Every request checks for it** (it grants read on the `DA Query Access` table, and table permissions are always enforced), so without it nothing runs: the builder shows "You don't have permission to query", and REST calls fail with *No permission: … Ask your system administrator to assign you the DA QUERY permission set.* It opens no business data by itself: people still need read permission on the tables they query. |
| `DA QUERY ADMIN` | DA QUERY, plus reading and clearing the Query Log. |

SUPER includes both. A service calling the REST endpoints needs `DA QUERY` on its app user (Microsoft Entra Applications page), plus read permission on the tables it queries.

## Install

You need permission to manage extensions in the environment (for example **D365 EXTENSION MGT** or **SUPER**). Try it in a sandbox first.

1. From the [latest release](https://github.com/garethcheyne/Dynamic-Assist_BusinessCentralAddon/releases/latest), download the **Apps** zip and unzip it. It holds the `.app` file.
2. In Business Central, search for **Extension Management**, then choose **Manage** → **Upload Extension**.
3. Pick the `.app` file, leave **Deploy to** on **Current version**, accept the terms and choose **Deploy**.
4. Check progress under **Manage** → **Deployment Status**. It's done when the app shows as installed on the Extension Management page.
5. Give users the **DA QUERY** permission set, alongside their normal permissions: open **Users**, pick a user and add it under **User Permission Sets** (or add it to a security group's permissions). Give admins **DA QUERY ADMIN** too, to read and clear the query log.

To update, upload the newer file the same way. Data (the query log) is kept.

### From source (development)

1. Open `al.code-workspace` (or the `DynamicAssistCompanion` folder) in VS Code with the AL Language extension.
2. In `DynamicAssistCompanion`, copy `.vscode/launch.example.json` to `.vscode/launch.json` and fill in your sandbox's name and tenant.
3. **AL: Download Symbols**, then **F5** (or **Ctrl+F5**) to publish to the sandbox.


### Builds and releases

This repository uses [AL-Go for GitHub](https://github.com/microsoft/AL-Go) (the per-tenant extension template). Its settings are in [.AL-Go/settings.json](.AL-Go/settings.json):

- **CI/CD** runs on every push to `main`, `release/*` and `feature/*`, and on pull requests. It compiles without a container (`useCompilerFolder`), with **CodeCop**, **UICop** and **PerTenantExtensionCop** on, and fails on errors. The app is kept as the run's artifact.
- **Versions** come from `app.json` for the first three parts and the CI/CD run number for the last (`versioningStrategy` 3): `2026.9.30.57`. Change the first three in `app.json`.
- **Releases**: run **Actions → Create release**, pick the CI/CD build to release and give it a tag (for example `2026.9.30`). The release gets the app as a zip and generated notes, and becomes the latest release that the extension links to.
- **Update AL-Go System Files** brings in Microsoft's newer AL-Go workflows.

There are no tests yet (`doNotRunTests`), so builds don't need a Business Central container.

## Use

In the Dynamic Assist side panel on Business Central, click the database icon in the environment bar, or **Query this table** on the Page tab. The builder opens over the page you're on and reaches the companion through a tab on the **Dynamic Assist Query** page of the same environment and company, opening one in the background the first time. Opening that page yourself (Alt+Q, "Dynamic Assist Query") also opens the builder over it.

## Couplings (Dataverse integration records)

`DA Coupling API` shows Business Central's side of the Dataverse integration: which records are coupled to which Dataverse rows (CRM Integration Record, table 5331), with each coupled record's table, primary key, the page to open it on, and when it last synced.

```http
GET https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/err403/dynamicassist/v1.0/companies({companyId})/couplings?$filter=crmId eq '{Dataverse row ID}'
GET …/couplings?$filter=integrationId eq '{Business Central record SystemId}'
GET …/couplings({id})
```

| Field | What it is |
| --- | --- |
| `id` | The integration record's SystemId (the key) |
| `crmId` | The Dataverse row's ID, as text (lowercase, no braces) |
| `integrationId` | The Business Central record's SystemId, as text |
| `tableId`, `tableCaption` | The Business Central table |
| `recordKey` | The record's primary key values, such as `10000` or `Order · 1001` |
| `recordFilter` | The same as a web client filter: `'No.' IS '10000'` (use it with `&page={pageId}&filter=`) |
| `pageId` | The page to open it on: the table mapping's record page, else the table's drill-down or lookup page |
| `recordExists` | False when the record is gone, or you can't read its table |
| `skipped`, `lastSynchModifiedOn`, `lastSynchCrmModifiedOn` | Sync state, as the integration keeps it |

Filter on `crmId` or `integrationId`, or get one by `id`; without a filter it pages through every coupling in the company. It's read-only, runs as the caller, and needs DA QUERY plus read permission on the integration tables and the coupled tables. Nothing needs publishing: API pages are available as soon as the app is installed.

**As a Dataverse virtual table.** `crmId` and `integrationId` are text, not GUIDs: the Business Central Virtual Table app drops GUID fields other than the key, and Dataverse needs to filter on them. After updating the app, **Refresh** the table under Available Tables so Dataverse picks up the columns. Its identifiers are lowercase and its key is one GUID (the integration record's SystemId), which the Virtual Table app needs, so with that app installed it's listed under **Available Business Central Tables** (in the Business Central Configuration app). Make it visible and Dataverse can read couplings like any table: no Business Central tab, no token.

## Take a query elsewhere

The query builder's **API** tab shows the query as a REST request, and picks the best way to run it:

1. **An API that's already installed** (Microsoft's, an ISV's or yours) when one covers the query: the companion lists every API page for the table and the JSON name each gives its fields, so the tab builds `$select`, `$filter` and `$top` in that API's names. Nothing to deploy.
2. **The Dynamic Assist endpoint**: one web service for any query (below).
3. **A custom API query**: an AL `query` object of type API, on the **AL** tab, to add to your own extension. Joins become nested data items (`DataItemLink`, `SqlJoinType`); filters OData can't express are set with `SetFilter` inside it.

## The Dynamic Assist endpoint (query any table over REST)

`DA Query API` puts the query builder's engine behind one web service, like FetchXML over the Dataverse Web API. It's off until you publish it: **Web Services** page → New → Object Type `Codeunit`, Object ID `77502`, Service Name `DAQuery`, Published.

```http
POST https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/ODataV4/DAQuery_Run?company={company}
Authorization: Bearer {token}
Content-Type: application/json

{ "request": "{\"table\":\"Customer\",\"fields\":[\"No.\",\"Name\"],\"filters\":[{\"field\":\"No.\",\"filter\":\">20000\"}],\"joins\":[{\"field\":\"Salesperson Code\",\"fields\":[\"Name\"]}],\"top\":100}" }
```

The answer's `value` is the result as JSON text: `columns`, and `rows` as objects keyed by field name (joined ones as `"Salesperson/Purchaser.Name"`).

The same works as a **GET**, with the query in the URL (up to 2,048 characters):

```http
GET https://api.businesscentral.dynamics.com/v2.0/{tenant}/{environment}/api/err403/dynamicAssist/v1.0/companies({companyId})/queryRows?$filter=request eq '{"table":"Customer","fields":["No.","Name"],"top":10}'&$select=rowNo,data
```

Each result row is an entity: `rowNo`, and `data`, the record as JSON text. The GET endpoint is on only while the `DAQuery` web service is published, so one switch controls both.

## Query log

Every query, from the query builder or either REST endpoint, is logged in **Dynamic Assist Query Log** (search for it, or **Query Log** on the Dynamic Assist Query page): who ran it, the channel, the company, the table, the request, rows returned, duration, and the error if it failed. Failed calls are logged too. Users can only add entries; reading and clearing the log takes **DA QUERY ADMIN**. **Delete Entries Older Than 30 Days** keeps it small.

- Tables and fields go **by name or number**. A wrong one is an error that says so: `Table Customer has no field "Nmae".`
- Filters use Business Central's syntax, exactly as in the builder.
- A join needs only the lookup field; the related table and key come from its table relation (give `table` and `key` to override). `inner: true`, or any filter on the related table, keeps only rows with a match.
- **Paging:** a call returns one page, 1,000 rows by default, `top` up to 5,000. When more match, the answer has `"more": true` and a `"next"` cursor: send the same request with `"after": next` for the following page, until `next` is gone. The cursor is a record position, so pages don't overlap or skip when records change between calls. Over GET, every row carries `more` and `next`.
- **Explore first:** `method` can also be `tables` (add `"search": "ledger entry"` to narrow it), `describe` (with `table`: fields, keys, the lookups you can join through with their table and key, whether you can read it, and the APIs already installed for it), `fields`, `apis` or `info`. They work over GET and POST, so anyone with a token can find out what they can query.
- **Joins match on the lookup's table relation.** A relation that depends on another field (Sales Line `No.` is an Item, G/L Account or Resource depending on `Type`) needs `"table"` and `"key"` given. A related table whose key has several fields (Dimension Value: Dimension Code + Code) is matched on the relation's field only; `describe` notes it.
- It runs **as the caller, read-only**: their permissions and security filters apply, to joined tables too. A service principal needs `DA QUERY` plus read permission on the tables it queries.

## How the bridge works

```
Side panel ──(inject)──► query builder (top frame, extension)
                              │ postMessage (ping / request)
                              ▼
                   DA Bridge add-in frame ──InvokeExtensibilityMethod──► AL (DA Query Service)
                              ▲                                              │
                              └──────────── Respond(id, ok, json) ◄──────────┘
```

Messages carry `tag: "dynamic-assist"`. The add-in accepts them only from `https://businesscentral.dynamics.com` and replies only to the frame that asked.

Requests: `info`, `tables`, `fields { table }`, and `query { table, fields, filters: [{ field, filter }], sort, descending, top, count }`. Filters use Business Central's syntax (`10000..20000`, `A*|B*`, `<>''`). A query returns at most 10,000 rows.
