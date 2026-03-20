# kwtSMS SMS Gateway for Salesforce

A free Salesforce AppExchange plugin that integrates the kwtSMS SMS gateway into your Salesforce org, enabling automated SMS notifications for orders, cases, and custom flows.

## Features

- **5-tab admin UI**: Dashboard, Settings, Gateway, Logs, Help, all inside a single Lightning App
- **Order and Case notifications**: Send SMS automatically when orders or cases are created or updated
- **Flow Builder integration**: Drag-and-drop "Send SMS via kwtSMS" invocable action usable in any Salesforce Flow
- **English and Arabic support**: Full bilingual UI and message templates
- **Bulk SMS**: Queue-based bulk sending with Queueable overflow handling for large recipient lists
- **SMS template management**: Reusable templates with placeholder variables
- **Full SMS logging**: Searchable activity log with status filtering
- **Daily sync job**: Automatic balance, sender ID, and coverage refresh via scheduled Apex

## Prerequisites

- A Salesforce org running Sales Cloud or Service Cloud (Enterprise Edition or higher recommended)
- An active kwtSMS account. Sign up at [kwtsms.com](https://kwtsms.com)
- Salesforce CLI (`sf`) installed for local development

## Installation

AppExchange listing: TBD (coming soon)

Once published, install directly from AppExchange with one click. No code deployment required.

## Configuration

1. After installation, open the **kwtSMS** Lightning App from the App Launcher.
2. Go to the **Settings** tab and enter your kwtSMS API credentials.
3. Click **Connect** on the **Gateway** tab to validate the connection.
4. Configure notification templates on the **Settings** tab.
5. Assign the `KwtSMS Admin` or `KwtSMS User` permission set to relevant users.

## Local Development

```bash
# Clone the repository
git clone <repo-url>
cd kwtsms_salesforce

# Run the setup script
bash scripts/setup.sh
```

See `scripts/setup.sh` for the full step-by-step dev environment setup.

## Links

- Website: [kwtsms.com](https://kwtsms.com)
- Support: support@kwtsms.com

## License

MIT License. See LICENSE for details.
