import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// Inicio de sesión / registro con correo y contraseña (Supabase Auth).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registrando = false;
  bool _cargando = false;
  String? _mensaje;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.length < 6) {
      setState(() => _mensaje =
          'Ingrese un correo y una contraseña de al menos 6 caracteres.');
      return;
    }

    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    try {
      if (_registrando) {
        final pendiente = await SupabaseService.registrar(email, password);
        if (pendiente && mounted) {
          setState(() {
            _registrando = false;
            _mensaje =
                'Cuenta creada. Revise su correo ($email) y confirme la '
                'cuenta; luego inicie sesión.';
          });
        }
      } else {
        await SupabaseService.iniciarSesion(email, password);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _mensaje = e.message);
    } catch (e) {
      if (mounted) setState(() => _mensaje = 'Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Delta RETIE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _registrando ? 'Crear cuenta' : 'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _enviar(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_mensaje != null) ...[
                    Text(
                      _mensaje!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registrando ? 'CREAR CUENTA' : 'ENTRAR'),
                  ),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => setState(() {
                              _registrando = !_registrando;
                              _mensaje = null;
                            }),
                    child: Text(_registrando
                        ? '¿Ya tiene cuenta? Iniciar sesión'
                        : '¿No tiene cuenta? Crear una'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
