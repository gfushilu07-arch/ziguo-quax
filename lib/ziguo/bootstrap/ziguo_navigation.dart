import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/ui/errors.dart';

import '../features/diagnostics/content_probe_screen.dart';
import '../integration/quax/quax_x_content_gateway.dart';

const ziguoContentProbeEnabled = bool.fromEnvironment('ZIGUO_CONTENT_PROBE');

Widget buildZiguoProbe(BuildContext context) {
  final gateway = QuaXXContentGateway(loadTweet: (id) => Twitter.getTweet(id));
  return ContentProbeScreen(
    gateway: gateway,
    inspector: gateway,
    onLogin: () => openAddAccount(context),
  );
}
