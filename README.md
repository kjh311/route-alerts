# Haul Alerts 🚛💨

Haul Alerts is a high-utility safety application specifically designed for commercial truck drivers on dedicated routes. It automates the critical "morning weather check," ensuring drivers are alerted to high-risk conditions before they hit the road.

## 🌟 Key Features

- **Automated Weather Scanning**: Automatically checks your specific route for high-risk conditions like extreme wind, snow, ice, and tornado warnings.
- **Shift-Window Logic**: Instead of static checks, the app scans weather thresholds across your entire shift window using a "Worst Case Window" approach.
- **Traffic & Construction**: Real-time monitoring of road incidents and construction delays via Google Maps API.
- **Color-Coded Status Dashboard**: Instant visual feedback (Green/Yellow/Red) on today's route outlook.
- **Customizable Routes**: Fine-tune your route by adding or removing specific checkpoints and mile markers.
- **Premium Alerts**: Integration with RevenueCat for pro-tier weather and traffic monitoring features.

## 🛠️ Tech Stack

- **Frontend**: Flutter (iOS & Android)
- **Backend**: [Supabase](https://supabase.com/)
  - PostgreSQL Database
  - Supabase Auth (Google & Apple Sign-In)
  - Edge Functions (Alert Engine & API Proxy)
- **Payments**: [RevenueCat](https://www.revenuecat.com/)
- **External APIs**:
  - **Google Maps Routes API**: Pathfinding, Snapping to Road, and Traffic Incidents.
  - **Weather**: OpenWeatherMap or Tomorrow.io for hourly forecasted conditions.

## 📁 Data Architecture

The backend is powered by Supabase with Row Level Security (RLS) ensuring data privacy.

- **`profiles`**: Stores user-specific settings, FCM tokens for push notifications, and subscription status synced via RevenueCat.
- **`routes`**: Stores driver route configurations, including checkpoints, shift times, and custom safety thresholds (e.g., wind speed limits).

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional, for local development)

### Backend Setup

1. Create a new project in [Supabase](https://app.supabase.com).
2. Apply the initial migrations found in `/supabase/migrations`.
3. Configure Auth providers (Google/Apple) in the Supabase Dashboard.

### Mobile App Setup

1. `flutter pub get`
2. Configure your environment variables for Supabase and RevenueCat.
3. `flutter run`

---

Built for drivers who value safety and efficiency.
