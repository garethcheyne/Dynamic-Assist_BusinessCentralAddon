The Business Central app that goes with the [Dynamic Assist](https://github.com/garethcheyne/Dynamic-Assist) browser extension. It adds read-only querying of any table you're allowed to read, plus the extension's **All fields**, **Dynamics 365 record** and app-name features.

**Read-only, and your permissions apply.** It lists tables and fields and reads records as the signed-in user, with their security filters. The only thing it writes is its own query log. It adds no web services until an admin publishes one.

## Install

You need permission to manage extensions in the environment (for example **D365 EXTENSION MGT** or **SUPER**). Try it in a sandbox first.

1. Download **{{ZIP}}** below and unzip it. (GitHub doesn't allow `.app` files as downloads, so the app comes zipped.)
2. In Business Central, search for **Extension Management**, then choose **Manage** → **Upload Extension**.
3. Pick **{{FILE}}**, leave **Deploy to** on **Current version**, accept the terms and choose **Deploy**.
4. Check progress under **Manage** → **Deployment Status**. It's done when the app shows as installed on the Extension Management page.
5. Give users the **DA QUERY** permission set, alongside their normal permissions: open **Users**, pick a user and add it under **User Permission Sets** (or add it to a security group's permissions). Give admins **DA QUERY ADMIN** too, to read and clear the query log.

To update, upload the newer file the same way. Data (the query log) is kept.

## Use

Install the Dynamic Assist browser extension, open Business Central and click the database icon in the side panel, or **Query this table** on its Page tab. The builder opens the **Dynamic Assist Query** page by itself.

Details: [bc-companion README](https://github.com/garethcheyne/Dynamic-Assist/tree/main/bc-companion).

---

Version {{VERSION}} · publisher ERR403 · object IDs 77500–77509 · Business Central 2024 wave 2 (platform 25) or later · per-tenant extension, not from AppSource
