                               ┌────────────────────┐
                               │     USER_ROLES     │
                               ├────────────────────┤
                               │ PK role_id         │
                               │ role_name          │
                               └─────────┬──────────┘
                                         │ 1
                                         │
                                         │ N
                                         ▼
                               ┌────────────────────┐
                               │       USERS        │
                               ├────────────────────┤
                               │ PK user_id         │
                               │ user_code          │
                               │ google_id          │
                               │ university_id      │
                               │ full_name          │
                               │ email              │
                               │ phone              │
                               │ password_hash      │
                               │ FK role_id         │
                               │ user_status        │
                               │ created_at         │
                               │ last_login         │
                               └────────────────────┘


┌────────────────────┐                     ┌────────────────────┐
│RESOURCE_CATEGORIES │                     │ RESOURCE_STATUS    │
├────────────────────┤                     ├────────────────────┤
│ PK type_id         │                     │ PK resource_status │
│ type_name          │                     │ resource_status_nm │
└─────────┬──────────┘                     └─────────┬──────────┘
          │ 1                                        │ 1
          │                                          │
          │ N                                        │ N
          ▼                                          ▼

             ┌──────────────────────────────────┐
             │            RESOURCES             │
             ├──────────────────────────────────┤
             │ PK resource_id                   │
             │ resource_code                    │
             │ resource_name                    │
             │ FK type_id                       │
             │ location                         │
             │ FK resource_status_id            │
             │ capacity                         │
             │ quantity                         │
             │ description                      │
             │ created_at                       │
             └──────────────────────────────────┘


                    ┌────────────────────┐
                    │  SCHEDULE_STATUS   │
                    ├────────────────────┤
                    │ PK schedule_status │
                    │ schedule_name      │
                    └────────────────────┘


                    ┌────────────────────┐
                    │  BOOKING_STATUS    │
                    ├────────────────────┤
                    │ PK booking_status  │
                    │ booking_status_nm  │
                    └────────────────────┘


                    ┌────────────────────┐
                    │ BOOKING_ACTIONS    │
                    ├────────────────────┤
                    │ PK action_id       │
                    │ action_name        │
                    └────────────────────┘



═══════════════════════════════════════════════
ROOM BOOKING MODULE
═══════════════════════════════════════════════

RESOURCES
     │
     │ 1:N
     ▼

┌────────────────────┐
│   ROOM_SCHEDULES   │
├────────────────────┤
│ PK schedule_id     │
│ FK resource_id     │
│ work_date          │
│ start_time         │
│ end_time           │
│ max_slots          │
│ FK schedule_status │
│ created_at         │
└─────────┬──────────┘
          │ 1:N
          ▼

┌────────────────────┐
│   ROOM_BOOKINGS    │
├────────────────────┤
│ PK booking_id      │
│ booking_code       │
│ FK user_id         │
│ FK schedule_id     │
│ FK booking_status  │
│ booking_time       │
│ booking_purpose    │
└─────────┬──────────┘
          │ 1:N
          ▼

┌────────────────────┐
│ROOM_BOOKING_HISTORY│
├────────────────────┤
│ PK history_id      │
│ FK booking_id      │
│ FK action_id       │
│ action_date        │
└────────────────────┘



═══════════════════════════════════════════════
3D PRINTER BOOKING MODULE
═══════════════════════════════════════════════

RESOURCES
     │
     │ 1:N
     ▼

┌────────────────────┐
│ PRINTER_SCHEDULES  │
├────────────────────┤
│ PK schedule_id     │
│ FK resource_id     │
│ work_date          │
│ start_time         │
│ end_time           │
│ max_slots          │
│ FK schedule_status │
│ created_at         │
└─────────┬──────────┘
          │ 1:N
          ▼

┌────────────────────┐
│ PRINTER_BOOKINGS   │
├────────────────────┤
│ PK booking_id      │
│ booking_code       │
│ FK user_id         │
│ FK schedule_id     │
│ FK booking_status  │
│ booking_time       │
│ print_purpose      │
└─────────┬──────────┘
          │ 1:N
          ▼

┌────────────────────────┐
│PRINTER_BOOKING_HISTORY │
├────────────────────────┤
│ PK history_id          │
│ FK booking_id          │
│ FK action_id           │
│ action_date            │
└────────────────────────┘



═══════════════════════════════════════════════
EQUIPMENT BORROWING MODULE
═══════════════════════════════════════════════

RESOURCES
     │
     │ 1:N
     ▼

┌────────────────────────┐
│  EQUIPMENT_BOOKINGS    │
├────────────────────────┤
│ PK booking_id          │
│ booking_code           │
│ FK user_id             │
│ FK resource_id         │
│ borrow_date            │
│ expected_return_date   │
│ actual_return_date     │
│ FK booking_status_id   │
│ borrow_purpose         │
└──────────┬─────────────┘
           │ 1:N
           ▼

┌────────────────────────────┐
│EQUIPMENT_BOOKING_HISTORY   │
├────────────────────────────┤
│ PK history_id              │
│ FK booking_id              │
│ FK action_id               │
│ action_date                │
└────────────────────────────┘

           │ 1:N
           ▼

┌────────────────────┐
│       FINES        │
├────────────────────┤
│ PK fine_id         │
│ FK booking_id      │
│ fine_amount        │
│ fine_reason        │
│ fine_status        │
└────────────────────┘



═══════════════════════════════════════════════
MAINTENANCE MANAGEMENT MODULE
═══════════════════════════════════════════════

RESOURCES
     │
     │ 1:N
     ▼

┌──────────────────────────┐
│ MAINTENANCE_BOOKINGS     │
├──────────────────────────┤
│ PK booking_id            │
│ booking_code             │
│ FK user_id               │
│ FK resource_id           │
│ booking_time             │
│ FK booking_status_id     │
│ repair_title             │
│ repair_description       │
│ reported_date            │
│ staff_note               │
└──────────┬───────────────┘
           │ 1:N
           ▼

┌─────────────────────────────┐
│MAINTENANCE_BOOKING_HISTORY  │
├─────────────────────────────┤
│ PK history_id               │
│ FK booking_id               │
│ FK action_id                │
│ action_date                 │
└─────────────────────────────┘

           │ 1:N
           ▼

┌────────────────────┐
│    ATTACHMENTS     │
├────────────────────┤
│ PK attachment_id   │
│ FK booking_id      │
│ file_name          │
│ file_path          │
│ upload_date        │
└────────────────────┘