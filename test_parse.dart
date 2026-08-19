import 'dart:convert';
import 'lib/models/demo_contest/demo_contest_model.dart';

void main() {
  final jsonStr = '''
  {
    "status": true,
    "data": [
        {
            "contest": {
                "id": 2,
                "trading_platform": "WEB_TRADER",
                "mt5_group_id": 10,
                "name": "contest one",
                "tagline": "complete contest and win prices",
                "start_date": "2026-08-03",
                "end_date": "2026-08-31",
                "starting_balance": 10000,
                "max_participants": 1000,
                "max_participations_per_user": 2,
                "auto_disqualify_on_violation": false,
                "min_participants": 1,
                "ranking_by": "return_percent",
                "registration_closes": "2026-08-10",
                "timezone": "Dubai Time (UTC+4)",
                "rules_who_can_register": "all_clients",
                "rules_kyc_required": "level2",
                "rules_kyc_claim": "yes_level2",
                "rules_real_account_required": true,
                "rules_countries_excluded": "",
                "trading_min_duration": 3,
                "trading_max_leverage": "1:200",
                "use_group_leverage": false,
                "trading_max_lots": 10,
                "use_group_max_lots": false,
                "trading_max_positions": 5,
                "trading_instruments": "all",
                "trading_strategies_disallowed": [],
                "show_portal": true,
                "send_push": true,
                "show_agency": true,
                "alert_sales": true,
                "status": "active",
                "enrollment_type": "free",
                "enrollment_fee": 0,
                "enrollment_start_date": null,
                "enrollment_end_date": null,
                "contest_start_date": null,
                "contest_end_date": null,
                "allow_multiple_contests": true,
                "created_by_type": "admin",
                "created_by_id": null,
                "ib_approval_status": null,
                "ib_admin_share_percent": 20,
                "prize_pool_type": "fixed",
                "prize_pool_distributed": 0,
                "prize_pool_is_distributed": false,
                "enrollment_steps_enabled": false,
                "terms_enabled": true,
                "terms_content": "check terms and condition according to demo contest",
                "cancelled_at": null,
                "cancel_reason": null,
                "created_at": "2026-08-04T06:23:54+00:00",
                "updated_at": "2026-08-07T05:40:50+00:00",
                "my_enrollment_status": "approved",
                "my_participant_id": 2,
                "enrollment_is_open": false,
                "can_cancel": true,
                "prizes": [
                    {
                        "id": 13,
                        "contest_id": 2,
                        "rank_min": 1,
                        "rank_max": 1,
                        "prize_type": "cash",
                        "prize_amount": 5000,
                        "prize_percent": null,
                        "condition": null,
                        "created_at": "2026-08-07T05:40:50+00:00",
                        "updated_at": "2026-08-07T05:40:50+00:00"
                    }
                ],
                "enrollment_steps": [],
                "pool": {
                    "id": 2,
                    "contest_id": 2,
                    "total_collected": 0,
                    "creator_added": 0,
                    "total_pool": 0,
                    "distributed_amount": 0,
                    "remaining_amount": 0,
                    "is_distributed": false,
                    "distributed_at": null,
                    "created_at": "2026-08-04T06:23:54+00:00",
                    "updated_at": "2026-08-04T06:23:54+00:00"
                },
                "instruments": []
            },
            "is_enrolled": true,
            "participant": {
                "id": 2,
                "contest_id": 2,
                "user_id": 9,
                "demo_account_number": "10414620",
                "starting_balance": 10000,
                "current_equity": 10000,
                "return_percent": 0,
                "profit": 0,
                "lots_traded": 0,
                "open_trades_count": 0,
                "is_disqualified": false,
                "disqualification_reason": null,
                "converted_to_real": false,
                "real_account_number": null,
                "real_ftd_amount": 0,
                "sales_agent_id": null,
                "enrollment_date": "2026-08-04T06:48:08+00:00",
                "enrollment_status": "approved",
                "enrollment_fee_paid": 0,
                "wallet_transaction_id": null,
                "approved_by": null,
                "approved_at": null,
                "rejection_reason": null,
                "tasks_completed": true,
                "terms_accepted": true,
                "terms_accepted_at": "2026-08-04T06:48:08+00:00",
                "created_at": "2026-08-04T06:48:08+00:00",
                "updated_at": "2026-08-04T06:48:08+00:00",
                "claim": null
            },
            "my_enrollments_count": 2,
            "max_participations": 2,
            "can_participate_again": false,
            "days_left": 0,
            "registration_open": false,
            "days_until_start": 0,
            "is_upcoming": false,
            "is_ended": false
        }
    ]
  }
  ''';
  
  try {
    final parsed = jsonDecode(jsonStr);
    final list = parsed['data'] as List;
    final contest = DemoContest.fromJson(list[0]);
    print('Success: ${contest.title}');
  } catch(e, st) {
    print('Error: $e');
    print(st);
  }
}
