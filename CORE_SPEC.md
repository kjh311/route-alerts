CORE_SPEC.md: Haul Alerts (MVP v1.3)

Haul Alerts is a high-utility safety application for commercial truck drivers on dedicated routes. It automates the "morning weather check" by scanning a specific route for high-risk conditions (wind, snow, ice, tornadoes) and construction delays during the driver's shift window.

2. Core Tech Stack
Frontend: Flutter (iOS/Android)

Backend: Supabase (PostgreSQL, Auth, Edge Functions)

Payments/Subs: RevenueCat (Entitlement: pro_alerts)

APIs: Google Maps Routes API (Pathfinding & Incidents), OpenWeatherMap or Tomorrow.io (Hourly Weather).

3. Authentication & Onboarding
Provider: Supabase Auth.

Methods: Google Sign-In and Apple Sign-In.

Flow: 1. Social Login.
2. Check for active subscription via RevenueCat.
3. If no subscription, show Paywall.
4. If active, proceed to Route Dashboard.

4. Subscription Logic (RevenueCat)
Entitlement: pro_alerts.

Products: Weekly, Monthly, and Yearly tiers.

Gatekeeping: * The Edge Function running the scan MUST verify the user's subscription status before calling Weather/Maps APIs.

Flutter UI must reactively show/hide the "Add Route" button based on active subscription status.

5. Data Architecture (Supabase)
Table: profiles

Column,Type,Description
id,uuid,Primary Key (Matches Auth UID)
fcm_token,text,For Push Notifications
subscription_status,text,active or expired (Synced via RevenueCat)
revenue_cat_id,text,Link to billing profile

Column,Type,Description
id,uuid,Primary Key
user_id,uuid,References profiles.id
start_location,text,"e.g., ""Albuquerque, NM"""
end_location,text,"e.g., ""Amarillo, TX"""
check_points,jsonb,Array of lat/lng and city names
shift_start_time,time,"e.g., 06:00:00"
shift_duration,int,"In hours (e.g., 8)"
active_days,int[],"e.g., [1,2,3,4,5] for Mon-Fri"
wind_threshold,int,Default: 45

6. The Alert Engine Logic
The engine uses a "Worst Case Window" approach rather than strict ETA calculations.

A. Weather Scanning (Shift-Window Rule)
Input: shift_start_time + shift_duration.

Process: For every checkpoint in routes.check_points, fetch hourly weather for that window.

Thresholds:

RED: Wind > wind_threshold, Tornado/Blizzard warnings, or Ice.

YELLOW: Rain, fog, light snow, or wind > 30mph.

GREEN: All clear.

Messaging: Construct strings like: "High wind (55mph) in Moriarty area between 10:00 AM and 1:00 PM."

B. Traffic & Construction
Logic: Pull all "Incidents" and "Traffic Congestion" for the route polyline.

Messaging: Identify work zones and total estimated delay (e.g., "20-minute delay: Construction on I-40 East MM 230.")

7. UI/UX Requirements
Status Dashboard: A giant color-coded card (Green/Yellow/Red) showing today's outlook.

Route Customization: A list-view of checkpoints where a driver can delete specific cities or add custom coordinates (Mile Markers).

Settings: Toggle notifications, change wind threshold, and manage subscription.

8. Functional Instructions for Antigravity (AI Coder)
Edge Function: Create a process-daily-alerts function triggered by a CRON schedule.

Maps Logic: Use Google Maps "Snap-to-Road" for all check_points.

Paywall: Implement a clean, native-feeling paywall using RevenueCat’s Purchases SDK.