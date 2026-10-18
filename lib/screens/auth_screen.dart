import 'package:flutter/material.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => busy = true);
    try {
      final app = AppScope.of(context);
      if (register) { await app.register(name.text, email.text, password.text); }
      else { await app.login(email.text, password.text); }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: SingleChildScrollView(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(padding: const EdgeInsets.all(26), child: Form(key: formKey, child:
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CircleAvatar(radius: 33, backgroundColor: AppColors.card,
              child: Icon(Icons.play_circle_fill, size: 48, color: AppColors.teal)),
          const SizedBox(height: 23),
          Text(register ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
          const SizedBox(height: 8),
          const Text('Your entertainment starts here', textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          if (register) ...[
            TextFormField(controller: name, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter your name' : null),
            const SizedBox(height: 12),
          ],
          TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
            validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email'),
          const SizedBox(height: 12),
          TextFormField(controller: password, obscureText: obscure,
            autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
            validator: (value) => (value ?? '').length < 6 ? 'At least 6 characters required' : null,
            onFieldSubmitted: (_) => submit()),
          const SizedBox(height: 22),
          FilledButton(onPressed: busy || demoMode ? null : submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.black,
              padding: const EdgeInsets.all(15)),
            child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(register ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.bold))),
          if (demoMode) const Padding(padding: EdgeInsets.only(top: 14), child:
            Text('Login is disabled in demo mode. Connect to a backend to enable accounts.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
          const SizedBox(height: 9),
          TextButton(onPressed: () => setState(() => register = !register),
            child: Text(register ? 'Already have an account? Sign in' : 'New here? Create an account')),
        ]),
      )),
    ))),
  );
}
