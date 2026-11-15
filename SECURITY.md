# Security

The Dynamic Assist Companion runs inside your Business Central environment, so a security problem in it matters. Please report one privately, not in a public issue.

## Reporting a vulnerability

Use GitHub's private reporting: on this repository's **Security** tab, choose **Report a vulnerability**. Only the maintainer sees the report.

Include what you can:

- the companion version (Extension Management shows it)
- what an attacker could do, and what they'd need first
- steps to reproduce it

You'll get an answer within a few days. A fix ships as a new release here, and the report is credited unless you'd rather it wasn't.

## Supported versions

Only the latest release gets security fixes. Update to it before reporting, if you can.

## What the app is designed to do

It's read-only and runs as the signed-in user, so Business Central's permissions and security filters always apply. Nothing runs without the DA QUERY permission set. The bridge only accepts messages from `https://businesscentral.dynamics.com`. The REST query endpoint is off until an admin publishes it. A way around any of these is a vulnerability.
