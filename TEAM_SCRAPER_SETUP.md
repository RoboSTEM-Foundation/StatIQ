# Team Master List Scraper Setup

This GitHub Action automatically scrapes team data from RobotEvents API and creates a master team list for your StatIQ app.

## What It Does

- **Scrapes real team data** from RobotEvents API for the seasons you're actually using:
  - Mix & Match (2025-2026) - Season ID 196
  - Rapid Relay (2024-2025) - Season ID 189  
  - Full Volume (2023-2024) - Season ID 180
- **Runs weekly** every Sunday at 2 AM UTC
- **Generates multiple data formats**:
  - `lib/data/master_team_list.json` - Complete team data with skills, events, awards
  - `lib/data/team_lookup.json` - Lightweight team lookup data
  - `lib/data/team_master_list.dart` - Dart constants for app integration
  - `lib/data/TEAM_UPDATE_REPORT.md` - Update report

## Setup Steps

### 1. ✅ API Key Already Configured

Great news! Your app already has **2 RobotEvents API keys** configured in `lib/constants/api_config.dart`. The GitHub Action is set up to use the first API key automatically.

### 2. Test the Workflow

1. Go to the **Actions** tab in your repository
2. Find "Update Team Master List" workflow
3. Click on it and then click **Run workflow**
4. Click the green **Run workflow** button
5. Monitor the progress in the Actions tab

### 3. Use in Your App

```dart
import 'package:stat_iq/services/team_master_list_service.dart';

// Get team information
final teamInfo = TeamMasterListService.instance.getTeamInfo('12345A');
if (teamInfo != null) {
  print('Team: ${teamInfo['name']}');
  print('Organization: ${teamInfo['organization']}');
  print('Location: ${teamInfo['location']}');
}

// Search teams
final searchResults = TeamMasterListService.instance.searchTeamsByName('Robotics');

// Check if team exists
bool exists = TeamMasterListService.instance.teamExists('12345A');

// Get all teams
final allTeams = TeamMasterListService.instance.getAllTeams();
```

## Schedule

The workflow runs automatically every **Sunday at 2 AM UTC**. You can also trigger it manually from the Actions tab.

## What Gets Scraped

For each team, the scraper collects:
- **Basic Info**: Team number, name, organization, location
- **Skills Data**: Driver and programming skills scores
- **Events**: All events the team has participated in
- **Awards**: Awards won by the team
- **Metadata**: Last updated timestamp, season information

## Rate Limiting

The scraper includes built-in rate limiting to respect the RobotEvents API:
- 1 second delay between page requests
- 2 second delay every 10 team enrichments
- 3 second delay between seasons
- Exponential backoff on errors

## Troubleshooting

### Common Issues

1. **API Key Invalid**
   - The API key is already configured in your app
   - If issues occur, check the Actions tab for error messages

2. **Rate Limiting**
   - The scraper includes built-in rate limiting
   - If you hit limits, the workflow will retry with exponential backoff

3. **No Teams Found**
   - Check that the season IDs are correct (196, 189, 180)
   - Verify the API is returning data for those seasons
   - Check the workflow logs for specific error messages

### Monitoring

- Check the Actions tab for workflow status
- Review the generated `TEAM_UPDATE_REPORT.md` for statistics
- Monitor the `lastUpdated` timestamp in the generated files

## Customization

### Modify Seasons

Edit `.github/workflows/update-team-master-list.yml` and update the `VEX_IQ_SEASONS` array:

```javascript
const VEX_IQ_SEASONS = [
  { id: 196, name: 'Mix & Match (2025-2026)' },
  { id: 189, name: 'Rapid Relay (2024-2025)' },
  { id: 180, name: 'Full Volume (2023-2024)' },
  // Add or remove seasons as needed
];
```

### Change Update Frequency

Modify the cron schedule in the workflow file:

```yaml
schedule:
  - cron: '0 2 * * 0'  # Every Sunday at 2 AM UTC
  # - cron: '0 2 * * *'  # Every day at 2 AM UTC
  # - cron: '0 2 1 * *'  # First day of every month at 2 AM UTC
```

## Data Usage

The generated data can be used for:

- **Team Lookup**: Quick team information retrieval
- **Search**: Find teams by name, location, or organization
- **Analytics**: Team distribution and statistics
- **Validation**: Verify team numbers and details
- **Offline Support**: Use team data without API calls

## Security Notes

- The API key is already configured in your app
- Generated data files are committed to the repository
- No sensitive information is included in the generated data
- The workflow runs in a secure GitHub Actions environment