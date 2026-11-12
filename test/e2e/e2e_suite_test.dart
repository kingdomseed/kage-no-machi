import 'package:flutter_test/flutter_test.dart';

import 'tier1_feature_coverage/t1_m0_baseline_engine_test.dart' as t1_m0;
import 'tier1_feature_coverage/t1_m1_shaders_look_test.dart' as t1_m1;
import 'tier1_feature_coverage/t1_m2_architecture_flora_test.dart' as t1_m2;
import 'tier1_feature_coverage/t1_m3_market_shrine_ui_test.dart' as t1_m3;
import 'tier1_feature_coverage/t1_m4_countryside_chunking_test.dart' as t1_m4;
import 'tier1_feature_coverage/t1_m5_capture_verification_test.dart' as t1_m5;
import 'tier2_boundary_corner/t2_m0_baseline_engine_edge_test.dart' as t2_m0;
import 'tier2_boundary_corner/t2_m1_shaders_look_edge_test.dart' as t2_m1;
import 'tier2_boundary_corner/t2_m2_architecture_flora_edge_test.dart' as t2_m2;
import 'tier2_boundary_corner/t2_m3_market_shrine_ui_edge_test.dart' as t2_m3;
import 'tier2_boundary_corner/t2_m4_countryside_chunking_edge_test.dart'
    as t2_m4;
import 'tier2_boundary_corner/t2_m5_capture_verification_edge_test.dart'
    as t2_m5;
import 'tier3_cross_feature/t3_pairwise_interactions_test.dart' as t3_pairwise;
import 'tier4_real_world_scenarios/t4_scenario_countryside_vista_test.dart'
    as t4_countryside;
import 'tier4_real_world_scenarios/t4_scenario_dusk_overview_test.dart'
    as t4_dusk;
import 'tier4_real_world_scenarios/t4_scenario_night_market_test.dart'
    as t4_night;
import 'tier4_real_world_scenarios/t4_scenario_river_gorge_test.dart'
    as t4_river;
import 'tier4_real_world_scenarios/t4_scenario_ui_lifecycle_test.dart' as t4_ui;

void main() {
  group('Kage no Machi — Master E2E Test Suite (Tiers 1–4)', () {
    group('Tier 1: Feature Coverage (115 Tests)', () {
      t1_m0.main();
      t1_m1.main();
      t1_m2.main();
      t1_m3.main();
      t1_m4.main();
      t1_m5.main();
    });

    group('Tier 2: Boundary & Corner Cases (115 Tests)', () {
      t2_m0.main();
      t2_m1.main();
      t2_m2.main();
      t2_m3.main();
      t2_m4.main();
      t2_m5.main();
    });

    group(
      'Tier 3: Cross-Feature Pairwise Interactions (23 Tests)',
      t3_pairwise.main,
    );

    group('Tier 4: Real-World Application Scenarios (5 Workloads)', () {
      t4_dusk.main();
      t4_night.main();
      t4_river.main();
      t4_countryside.main();
      t4_ui.main();
    });
  });
}
