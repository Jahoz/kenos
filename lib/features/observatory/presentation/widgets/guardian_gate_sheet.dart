import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';

/// The Seuil du Gardien — the Observatory's only door.
///
/// A glass threshold: the guardian's email and the long secret, once,
/// in memory. Nothing is stored, nothing is remembered. Refused words
/// are answered with ember warmth, never with destruction's rose.
class GuardianGatePanel extends StatefulWidget {
  const GuardianGatePanel({
    super.key,
    required this.onSubmit,
    this.busy = false,
    this.error,
  });

  final Future<void> Function(String email, String password) onSubmit;
  final bool busy;
  final String? error;

  @override
  State<GuardianGatePanel> createState() => _GuardianGatePanelState();
}

class _GuardianGatePanelState extends State<GuardianGatePanel> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(26),
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.fade(AppColors.voidBlackDeep, 0.86),
            border: Border.all(color: AppColors.hairlineStrong, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            container: true,
            label: 'Seuil du gardien de l\'observatoire',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LE SEUIL DU GARDIEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 11,
                    letterSpacing: 3,
                    color: AppColors.fade(AppColors.pureLight, 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'L\'astronome ne lit aucun message.\nIl compte les étoiles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.fade(AppColors.pureLight, 0.65),
                  ),
                ),
                const SizedBox(height: 30),
                _field(
                  controller: _email,
                  label: 'COURRIEL DU GARDIEN',
                  hint: 'gardien@…',
                  keyboard: TextInputType.emailAddress,
                  action: TextInputAction.next,
                  secret: false,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _password,
                  label: 'MOT DE PASSE',
                  hint: 'le long secret',
                  keyboard: TextInputType.visiblePassword,
                  action: TextInputAction.done,
                  secret: true,
                  focusNode: _passwordFocus,
                  onSubmitted: (_) => _submit(),
                ),
                if (widget.error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      letterSpacing: 1,
                      height: 1.7,
                      color: AppColors.fade(AppColors.ember, 0.85),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : () => _submit(),
                    // The sole CTA of the threshold carries its own
                    // light: full-contrast text on a teal hairline,
                    // legible on the dimmest OLED.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.pureLight,
                      side: BorderSide(
                        color: AppColors.fade(AppColors.teal, 0.45),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.busy ? '…' : 'FRANCHIR LE SEUIL',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboard,
    required TextInputAction action,
    required bool secret,
    FocusNode? focusNode,
    ValueChanged<String>? onSubmitted,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: AppColors.hairlineStrong, width: 1),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      textInputAction: action,
      obscureText: secret,
      autofillHints: secret ? null : const [AutofillHints.email],
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 13,
        color: AppColors.pureLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 9,
          letterSpacing: 2,
          color: AppColors.fade(AppColors.pureLight, 0.45),
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 12,
          color: AppColors.fade(AppColors.pureLight, 0.25),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: AppColors.fade(AppColors.teal, 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }
}
