/*
 * Dynamic Assist bridge. Runs in the control add-in's frame inside the
 * Business Central web client.
 *
 * The extension (in the page's top frame) posts to this frame:
 *   { tag: "dynamic-assist", type: "ping" }
 *   { tag: "dynamic-assist", type: "request", id, method, params }
 * and gets back { tag, type: "hello" } or { tag, type: "response", id, ok, result | error }.
 *
 * Only messages from Business Central's own origin are accepted, and replies
 * go only to the frame that asked, at that origin. AL does the work as the
 * signed-in user; this script only passes messages along, and draws the page:
 * what this is, whether the extension is connected and you have access, where
 * to get the extension, and how to call the REST endpoints, with examples.
 */
;(function () {
  "use strict"

  // Store listings: fill these in once the extension is published. An empty
  // link shows as "Coming soon".
  var LINKS = {
    chrome: "",
    edge: "",
    source: "https://github.com/garethcheyne/Dynamic-Assist",
    help: "https://github.com/garethcheyne/Dynamic-Assist/tree/main/bc-companion",
  }

  var TAG = "dynamic-assist"
  var BC_ORIGIN = "https://businesscentral.dynamics.com"
  var PROTOCOL = 1
  /** How long to wait for the extension before saying it isn't there */
  var DETECT_MS = 5000
  var callers = {}
  var connected = false
  var info = {}

  // --- Messages from the extension ---------------------------------------

  function allowed(origin) {
    return origin === BC_ORIGIN || origin === window.location.origin
  }

  window.addEventListener("message", function (event) {
    var data = event.data
    if (!data || data.tag !== TAG || !event.source || !allowed(event.origin)) {
      return
    }
    if (data.type === "ping") {
      setConnected()
      event.source.postMessage(
        { tag: TAG, type: "hello", protocol: PROTOCOL },
        event.origin
      )
      return
    }
    if (
      data.type === "request" &&
      typeof data.id === "string" &&
      typeof data.method === "string"
    ) {
      setConnected()
      callers[data.id] = { source: event.source, origin: event.origin }
      Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("Request", [
        data.id,
        data.method,
        JSON.stringify(data.params || {}),
      ])
    }
  })

  // Called from AL: CurrPage.Bridge.Respond(RequestId, Ok, Payload)
  window.Respond = function (id, ok, payload) {
    var caller = callers[id]
    delete callers[id]
    if (!caller) return
    var message = { tag: TAG, type: "response", id: id, ok: !!ok }
    if (ok) {
      try {
        message.result = JSON.parse(payload)
      } catch (e) {
        message.ok = false
        message.error = "The response wasn't valid JSON."
      }
    } else {
      message.error = payload || "The request failed."
    }
    caller.source.postMessage(message, caller.origin)
  }

  // Called from AL when the page opens: CurrPage.Bridge.SetInfo(Json)
  window.SetInfo = function (json) {
    try {
      info = JSON.parse(json) || {}
    } catch (e) {
      return
    }
    setText("da-version", info.version ? "Version " + info.version : "")
    setText("da-where", [info.company, info.user].filter(Boolean).join(" · "))

    var access = byId("da-access")
    if (info.hasAccess === false) {
      access.hidden = false
      setText(
        "da-access-text",
        (info.user || "You") +
          " doesn't have the DA QUERY permission set, so queries won't run. Ask your administrator to assign it (or DA QUERY ADMIN)."
      )
    }
    setPill(
      "da-perm-status",
      info.hasAccess === false ? "warn" : info.hasAccess ? "ok" : "",
      info.hasAccess === false
        ? "You don't have it"
        : info.hasAccess
          ? "You have access"
          : ""
    )

    var ws = info.webService
    if (!ws) setPill("da-ws-status", "", "Ask an admin")
    else if (ws.published)
      setPill("da-ws-status", "ok", "On: published as " + (ws.name || "DAQuery"))
    else setPill("da-ws-status", "warn", "Off: not published")
    renderExamples()
  }

  // --- Helpers --------------------------------------------------------------

  function byId(id) {
    return document.getElementById(id)
  }

  function setText(id, text) {
    var el = byId(id)
    if (el) el.textContent = text
  }

  function setPill(id, tone, text) {
    var el = byId(id)
    if (!el) return
    el.className = "da-pill" + (tone ? " da-pill-" + tone : "")
    el.textContent = text
    el.hidden = !text
  }

  function el(tag, className, text) {
    var node = document.createElement(tag)
    if (className) node.className = className
    if (text !== undefined) node.textContent = text
    return node
  }

  function copy(text, button) {
    function done() {
      var label = button.textContent
      button.textContent = "Copied"
      setTimeout(function () {
        button.textContent = label
      }, 1200)
    }
    function fallback() {
      var area = el("textarea")
      area.value = text
      area.style.position = "fixed"
      area.style.opacity = "0"
      document.body.appendChild(area)
      area.select()
      try {
        document.execCommand("copy")
        done()
      } catch (e) {
        // Leave it selected for Ctrl+C
      }
      document.body.removeChild(area)
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback)
    } else fallback()
  }

  function setStatus(kind, title, text) {
    byId("da-status").className = "da-banner da-banner-" + kind
    setText("da-status-title", title)
    setText("da-status-text", text)
  }

  function setConnected() {
    if (connected) return
    connected = true
    setStatus(
      "ok",
      "Dynamic Assist is connected",
      "The query builder opens over this page. Close it any time, and open it again from the Business Central side panel."
    )
  }

  // --- Where we are, for the examples -------------------------------------

  /** Tenant and environment from the web client's address (same origin) */
  function location() {
    var tenant = "{tenantId}"
    var environment = "{environment}"
    try {
      // Only the web client's own address says where we are
      if (window.top.location.hostname !== "businesscentral.dynamics.com") {
        return { tenant: tenant, environment: environment }
      }
      var parts = window.top.location.pathname.split("/").filter(Boolean)
      if (parts[0] && /^[0-9a-f-]{36}$|\./i.test(parts[0])) tenant = parts.shift()
      if (parts[0] && parts[0].toLowerCase() !== "admin") environment = parts[0]
    } catch (e) {
      // Another origin: keep the placeholders
    }
    return { tenant: tenant, environment: environment }
  }

  // --- The examples -----------------------------------------------------------

  function examples() {
    var where = location()
    var base =
      "https://api.businesscentral.dynamics.com/v2.0/" +
      where.tenant +
      "/" +
      where.environment
    var company = info.company || "{company}"
    var companyId = info.companyId || "{companyId}"
    var getUrl =
      base + "/api/err403/dynamicAssist/v1.0/companies(" + companyId + ")/queryRows"
    var postUrl =
      base + "/ODataV4/DAQuery_Run?company=" + encodeURIComponent(company)
    var auth = "Authorization: Bearer {token}"

    var simple = {
      table: "Customer",
      fields: ["No.", "Name", "Balance (LCY)"],
      filters: [{ field: "Balance (LCY)", filter: ">0" }],
      top: 100,
    }
    var getQuery = JSON.stringify(simple).replace(/'/g, "''")

    return [
      {
        id: "get",
        label: "GET",
        intro:
          "Put the query in the URL, in $filter=request eq '…' (up to 2,048 characters). Each result row comes back as an entity: data is the record as JSON text, keyed by field name.",
        code:
          "GET " +
          getUrl +
          "\n    ?$filter=request eq '" +
          getQuery +
          "'\n    &$select=rowNo,data,more,next\n" +
          auth,
        // Shown on three lines to read; Copy gives the one-line URL
        copyCode:
          getUrl +
          "?$filter=request eq '" +
          getQuery +
          "'&$select=rowNo,data,more,next",
        response:
          '{\n  "value": [\n    {\n      "rowNo": 1,\n      "data": "{\\"No.\\":\\"10000\\",\\"Name\\":\\"Adatum Corporation\\",\\"Balance (LCY)\\":1200.5}",\n      "more": true,\n      "next": "Field1=CONST(10000)"\n    }\n  ]\n}',
        note: "URL-encode the $filter value when you send it (most HTTP clients do). Quotes inside the query are doubled: O'Brien becomes O''Brien.",
      },
      {
        id: "post",
        label: "POST",
        intro:
          "Send the query in the body, as JSON text in request. No length limit. The answer's value is the result as JSON text: parse it once more.",
        code:
          "POST " +
          postUrl +
          "\n" +
          auth +
          "\nContent-Type: application/json\n\n" +
          JSON.stringify({
            request: JSON.stringify({
              table: "Customer",
              fields: ["No.", "Name"],
              filters: [{ field: "No.", filter: "10000..30000" }],
              sort: ["Name"],
              top: 1000,
            }),
          }),
        response:
          '{\n  "value": "{\\"table\\":18,\\"name\\":\\"Customer\\",\\"columns\\":[...],\\"rows\\":[{\\"No.\\":\\"10000\\",\\"Name\\":\\"Adatum Corporation\\"}],\\"more\\":false,\\"ms\\":42}"\n}',
      },
      {
        id: "joins",
        label: "Joins",
        intro:
          "Add columns from related tables through lookup fields. The related table and its key come from the field's table relation. A filter on the related table, or inner: true, keeps only rows with a match.",
        code: JSON.stringify(
          {
            table: "Sales Header",
            fields: ["Document Type", "No.", "Sell-to Customer No."],
            filters: [{ field: "Document Type", filter: "Order" }],
            joins: [
              { field: "Sell-to Customer No.", fields: ["Name", "City"] },
              {
                field: "Salesperson Code",
                fields: ["Name"],
                filters: [{ field: "Name", filter: "A*" }],
              },
            ],
          },
          null,
          2
        ),
        response:
          '"rows": [\n  {\n    "Document Type": "Order",\n    "No.": "101005",\n    "Sell-to Customer No.": "10000",\n    "Customer.Name": "Adatum Corporation",\n    "Customer.City": "Atlanta",\n    "Salesperson/Purchaser.Name": "Annette Hill"\n  }\n]',
      },
      {
        id: "paging",
        label: "Paging",
        intro:
          "A call returns one page: 1,000 rows by default, top up to 5,000. When more match, more is true and next is a cursor: send the same request with \"after\": next. It's a record position, so pages don't overlap or skip even if records change between calls.",
        code:
          'const url = "' +
          postUrl +
          '"\nconst query = { table: "G/L Entry", fields: ["Entry No.", "G/L Account No.", "Amount"], top: 5000 }\nconst rows = []\nlet after\ndo {\n  const res = await fetch(url, {\n    method: "POST",\n    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },\n    body: JSON.stringify({ request: JSON.stringify({ ...query, after }) }),\n  })\n  const body = await res.json()\n  if (!res.ok) throw new Error(body.error.message)\n  const page = JSON.parse(body.value)\n  rows.push(...page.rows)\n  after = page.next // not there on the last page\n} while (after)',
        note: "Over GET, every row carries the page's more and next; add \"after\" to the query in $filter for the next page.",
      },
      {
        id: "metadata",
        label: "Explore",
        intro:
          "Find out what's there before you query. Send these as the request, over GET or POST: search the tables, then describe one to see its fields (type, key, options), its keys, the lookups you can join through (with the related table and key named), whether you can read it, and the APIs already installed for it.",
        code:
          '{ "method": "tables", "search": "ledger entry" }\n{ "method": "describe", "table": "Customer" }\n{ "method": "fields", "table": "Customer" }\n{ "method": "apis", "table": "Customer" }\n{ "method": "info" }',
        copyCode: '{ "method": "describe", "table": "Customer" }',
        response:
          '{\n  "table": 18, "name": "Customer", "caption": "Customer", "readable": true,\n  "fields": [\n    { "no": 1, "name": "No.", "type": "Code", "class": "Normal", "length": 20, "pk": true, ... },\n    { "no": 59, "name": "Balance (LCY)", "type": "Decimal", "class": "FlowField", ... }\n  ],\n  "keys": [["No."], ["Search Name"], ...],\n  "joins": [\n    { "field": "Salesperson Code", "table": "Salesperson/Purchaser", "key": "Code" },\n    { "field": "Payment Terms Code", "table": "Payment Terms", "key": "Code" }\n  ],\n  "apis": [{ "publisher": "", "version": "v2.0", "entitySetName": "customers", ... }]\n}',
      },
      {
        id: "reference",
        label: "Reference",
        intro: "Everything a query can say. Tables and fields go by name or number.",
        table: [
          ["table", "The table: \"Customer\" or 18."],
          ["fields", "Columns to return. Empty: the primary key. FlowFields are calculated."],
          ["filters", "[{ \"field\": \"No.\", \"filter\": \"10000..20000\" }] in Business Central's own syntax: ranges, A*|B*, <>'', @case."],
          ["sort", "Fields to sort by; \"descending\": true to reverse."],
          ["top", "Rows per page: 1,000 by default over REST, 5,000 at most."],
          ["after", "The next cursor from the previous page."],
          ["count", "true: also count every matching record."],
          ["joins", "[{ \"field\": lookup field, \"fields\": [...], \"filters\": [...], \"inner\": true }]; \"table\" and \"key\" override the relation."],
          ["method", "query (default), tables, fields, apis or info."],
          ["shape", "objects (default over REST): rows keyed by field name. arrays: rows as arrays, in column order."],
        ],
      },
      {
        id: "errors",
        label: "Errors",
        intro:
          "Mistakes come back as a normal Business Central error, with a message that says what's wrong. Every call, failed or not, is in the Query Log.",
        code: '{\n  "error": {\n    "code": "Unhandled",\n    "message": "Table Customer has no field \\"Nmae\\"."\n  }\n}',
        list: [
          'There\'s no table called "Custmer".',
          'Table Customer has no field "Nmae".',
          'The filter "abc" is not valid for the Balance (LCY) field on the Customer table.',
          "You don't have permission to read G/L Entry (table 17).",
          "The caller doesn't have the DA QUERY permission set.",
          "Querying Business Central through Dynamic Assist is turned off (the DAQuery web service isn't published).",
          "The request isn't valid JSON.",
        ],
      },
    ]
  }

  var activeExample = "get"

  function renderExamples() {
    var host = byId("da-examples")
    if (!host) return
    host.textContent = ""
    var list = examples()
    var tabs = el("div", "da-tabs")
    tabs.setAttribute("role", "tablist")
    list.forEach(function (ex) {
      var tab = el("button", "da-tab", ex.label)
      tab.type = "button"
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", String(ex.id === activeExample))
      tab.addEventListener("click", function () {
        activeExample = ex.id
        renderExamples()
      })
      tabs.appendChild(tab)
    })
    host.appendChild(tabs)

    var ex = list.filter(function (x) {
      return x.id === activeExample
    })[0]
    var panel = el("div", "da-tab-panel")
    panel.setAttribute("role", "tabpanel")
    panel.appendChild(el("p", "", ex.intro))
    if (ex.code) panel.appendChild(codeBlock("Request", ex.code, ex.copyCode))
    if (ex.response) panel.appendChild(codeBlock("Response", ex.response))
    if (ex.table) {
      var table = el("table", "da-ref")
      ex.table.forEach(function (row) {
        var tr = el("tr")
        tr.appendChild(el("th", "", row[0]))
        tr.appendChild(el("td", "", row[1]))
        table.appendChild(tr)
      })
      panel.appendChild(table)
    }
    if (ex.list) {
      var ul = el("ul", "da-list da-errors")
      ex.list.forEach(function (item) {
        ul.appendChild(el("li", "", item))
      })
      panel.appendChild(ul)
    }
    if (ex.note) panel.appendChild(el("p", "da-muted", ex.note))
    host.appendChild(panel)
  }

  function codeBlock(title, text, copyText) {
    var wrap = el("div", "da-code-wrap")
    var head = el("div", "da-code-head")
    head.appendChild(el("span", "", title))
    var button = el("button", "da-copy", "Copy")
    button.type = "button"
    button.addEventListener("click", function () {
      copy(copyText || text, button)
    })
    head.appendChild(button)
    wrap.appendChild(head)
    wrap.appendChild(el("pre", "da-code", text))
    return wrap
  }

  // --- The page -------------------------------------------------------------

  function storeButton(label, sub, href) {
    if (href) {
      return (
        '<a class="da-store" target="_blank" rel="noopener" href="' +
        href +
        '"><span class="da-store-label">' +
        label +
        '</span><span class="da-store-sub">' +
        sub +
        "</span></a>"
      )
    }
    return (
      '<span class="da-store da-store-soon" aria-disabled="true"><span class="da-store-label">' +
      label +
      '</span><span class="da-store-sub">Coming soon</span></span>'
    )
  }

  var ICON =
    '<svg class="da-icon" viewBox="0 0 128 128" aria-hidden="true"><defs><linearGradient id="da-tile" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3fc1c4"/><stop offset="1" stop-color="#00585d"/></linearGradient></defs><rect x="4" y="4" width="120" height="120" rx="28" fill="url(#da-tile)"/><path fill="#fff" d="M60 22c3 21 11 32 32 36-21 4-29 15-32 36-3-21-11-32-32-36 21-4 29-15 32-36z"/></svg>'

  byId("controlAddIn").innerHTML =
    '<div class="da-page">' +
    // Header
    '<header class="da-header">' +
    ICON +
    '<div class="da-header-text">' +
    '<h1 class="da-title">Dynamic Assist Query</h1>' +
    '<p class="da-subtitle">Query any table you can read, from Business Central or from other services. <span id="da-where"></span></p>' +
    "</div>" +
    "</header>" +
    // Status
    '<div id="da-status" class="da-banner da-banner-wait" role="status">' +
    '<span class="da-dot"></span><div>' +
    '<div id="da-status-title" class="da-banner-title">Looking for the Dynamic Assist extension…</div>' +
    '<div id="da-status-text" class="da-banner-text">If it\'s installed in this browser, the query builder opens over this page in a moment.</div>' +
    "</div></div>" +
    '<div id="da-access" class="da-banner da-banner-error" role="alert" hidden>' +
    '<span class="da-dot"></span><div>' +
    '<div class="da-banner-title">You don\'t have access yet</div>' +
    '<div id="da-access-text" class="da-banner-text"></div>' +
    "</div></div>" +
    // How it works
    '<section class="da-card">' +
    "<h2>How it works</h2>" +
    '<ol class="da-steps">' +
    "<li><b>Install the browser extension</b> in Chrome or Edge. It adds a side panel with tools for Business Central, Dynamics 365 and Power Apps.</li>" +
    '<li><b>Open the query builder.</b> Click the database icon in the side panel, or open this page (search for "Dynamic Assist Query").</li>' +
    "<li><b>Pick a table, columns and filters</b>, join related tables, and run. Export to Excel, CSV or JSON, or copy the query as AL or a REST request.</li>" +
    "</ol>" +
    "</section>" +
    // Get it, safety, permissions
    '<div class="da-grid">' +
    '<section class="da-card">' +
    "<h2>Get the extension</h2>" +
    '<div class="da-stores">' +
    storeButton("Chrome Web Store", "For Google Chrome", LINKS.chrome) +
    storeButton("Microsoft Edge Add-ons", "For Microsoft Edge", LINKS.edge) +
    "</div>" +
    '<p class="da-muted">Free and open source. <a target="_blank" rel="noopener" href="' +
    LINKS.source +
    '">Source code on GitHub</a>.</p>' +
    "</section>" +
    '<section class="da-card">' +
    "<h2>Safe by design</h2>" +
    '<ul class="da-list">' +
    "<li><b>Read-only.</b> It never changes your data. The only thing it writes is its own Query Log.</li>" +
    "<li><b>Your permissions.</b> You see only the tables and rows you may read; security filters apply, to joined tables too.</li>" +
    "<li><b>Nothing leaves.</b> Queries run in your session and results go only to your browser, or to the service that called.</li>" +
    "</ul>" +
    "</section>" +
    '<section class="da-card">' +
    '<h2>Permissions <span id="da-perm-status" class="da-pill" hidden></span></h2>' +
    '<table class="da-ref da-perms">' +
    "<tr><th>DA QUERY</th><td>Needed to query at all, from the query builder or the REST endpoints. Every request checks for it. It opens no data by itself: people still need read permission on the tables they query.</td></tr>" +
    "<tr><th>DA QUERY ADMIN</th><td>DA QUERY, plus reading and clearing the Query Log.</td></tr>" +
    "</table>" +
    '<p class="da-muted">SUPER includes both. A service calling the REST endpoints needs DA QUERY on its app user in <b>Microsoft Entra Applications</b>, plus read permission on its tables.</p>' +
    "</section>" +
    "</div>" +
    // For developers
    '<section class="da-card">' +
    '<h2>Query from other services <span id="da-ws-status" class="da-pill">Checking…</span></h2>' +
    "<p>The query builder's engine is also a REST API, so integrations can query any table in one request, like FetchXML in Dataverse. " +
    "It's off until an admin turns it on: on the <b>Web Services</b> page, add Object Type <code>Codeunit</code>, Object ID <code>77502</code>, Service Name <code>DAQuery</code>, and tick <b>Published</b>. That switches on both GET and POST.</p>" +
    '<div id="da-examples" class="da-examples"></div>' +
    '<p class="da-muted">Every call is in the <b>Query Log</b> (on this page\'s action bar): who, what, how many rows, how long. The query builder\'s API tab writes these requests for you. <a target="_blank" rel="noopener" href="' +
    LINKS.help +
    '">Full documentation</a>.</p>' +
    "</section>" +
    '<footer class="da-footer"><span>Dynamic Assist Companion</span><span id="da-version"></span><span>Not affiliated with Microsoft</span></footer>' +
    "</div>"

  renderExamples()

  // No word from the extension: say so, and point at the download
  setTimeout(function () {
    if (connected) return
    setStatus(
      "warn",
      "The Dynamic Assist extension isn't running in this browser",
      "Install it from the Chrome Web Store or Microsoft Edge Add-ons, then reload this page. Already installed? Reload the page once after installing or updating it."
    )
  }, DETECT_MS)

  // Tell the extension this page can answer queries; it opens the builder
  try {
    window.top.postMessage(
      { tag: TAG, type: "hello", protocol: PROTOCOL, announce: true },
      BC_ORIGIN
    )
  } catch (e) {
    // No extension listening, or a different top origin: nothing to do
  }

  Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("Ready", [])
})()
