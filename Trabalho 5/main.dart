import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://barra.cos.ufrj.br/t5/rest';

void main() {
  runApp(const GerenciadorTarefasApp());
}

class GerenciadorTarefasApp extends StatelessWidget {
  const GerenciadorTarefasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Tarefas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

/// Extrai a mensagem de erro retornada pela API (campo 'message')
String extrairMensagemErro(String responseBody, String mensagemPadrao) {
  if (responseBody.trim().isEmpty) return mensagemPadrao;
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
  } catch (_) {}
  return mensagemPadrao;
}

// ============================================================================
// TELA DE LOGIN
// ============================================================================

class LoginScreen extends StatefulWidget {
  final String? mensagemInicial;

  const LoginScreen({super.key, this.mensagemInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erroMensagem;

  @override
  void initState() {
    super.initState();
    if (widget.mensagemInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.mensagemInicial!),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _irParaCadastro({String? emailPreenchido}) async {
    final emailCadastrado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CadastroScreen(
          emailInicial: emailPreenchido ?? _emailController.text.trim(),
        ),
      ),
    );

    if (emailCadastrado != null && emailCadastrado.isNotEmpty && mounted) {
      setState(() {
        _emailController.text = emailCadastrado;
        _senhaController.clear();
        _erroMensagem = null;
      });
    }
  }

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() {
        _erroMensagem = 'Preencha o e-mail e a senha.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erroMensagem = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rpc/fazer_login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'email': email,
          'senha': senha,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final String token = dados['token']?.toString() ?? '';
        // Usa sempre o email devolvido pelo login (em minúsculas)
        final String emailLogado =
            dados['email']?.toString() ?? email.toLowerCase();
        final String nomeUsuario = dados['nome']?.toString() ?? emailLogado;

        if (token.isEmpty) {
          setState(() {
            _erroMensagem = 'Erro: a API não retornou um token válido.';
          });
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ListaTarefasScreen(
              token: token,
              email: emailLogado,
              nome: nomeUsuario,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        final msg = extrairMensagemErro(
          response.body,
          'Credenciais inválidas.',
        );

        if (msg.toLowerCase().contains('não encontrado') ||
            msg.toLowerCase().contains('nao encontrado')) {
          setState(() {
            _erroMensagem = msg;
          });
          _mostrarDialogoUsuarioNaoEncontrado(email);
        } else {
          // Senha inválida
          setState(() {
            _erroMensagem = msg;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        final msg = extrairMensagemErro(
          response.body,
          'Erro ao fazer login (${response.statusCode}).',
        );
        setState(() {
          _erroMensagem = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroMensagem = 'Erro de conexão com o servidor: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _mostrarDialogoUsuarioNaoEncontrado(String emailDigitado) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuário não cadastrado'),
        content: Text(
          'O e-mail "$emailDigitado" ainda não está cadastrado.\n'
          'Deseja ir para a tela de cadastro agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _irParaCadastro(emailPreenchido: emailDigitado);
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - Lista de Tarefas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.checklist_rtl,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bem-vindo!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Entre com suas credenciais para acessar suas tarefas',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'usuario@exemplo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _fazerLogin(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultarSenha
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _ocultarSenha = !_ocultarSenha;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (_) => _fazerLogin(),
                      ),
                      if (_erroMensagem != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _erroMensagem!,
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _carregando ? null : _fazerLogin,
                        icon: _carregando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_carregando ? 'Entrando...' : 'Entrar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _carregando ? null : () => _irParaCadastro(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Não tem conta? Cadastre-se'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA DE CADASTRO
// ============================================================================

class CadastroScreen extends StatefulWidget {
  final String emailInicial;

  const CadastroScreen({super.key, this.emailInicial = ''});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final TextEditingController _nomeController = TextEditingController();
  late final TextEditingController _emailController;
  final TextEditingController _celularController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;
  String? _erroMensagem;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _celularController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrarUsuario() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final celular = _celularController.text.trim();
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    if (nome.length < 3) {
      setState(() {
        _erroMensagem = 'O nome deve ter no mínimo 3 caracteres.';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _erroMensagem = 'Informe um e-mail válido.';
      });
      return;
    }

    if (celular.isNotEmpty && celular.length < 8) {
      setState(() {
        _erroMensagem =
            'O número de celular deve ter no mínimo 8 caracteres.';
      });
      return;
    }

    if (senha.length < 8) {
      setState(() {
        _erroMensagem = 'A senha deve ter no mínimo 8 caracteres.';
      });
      return;
    }

    if (senha != confirmarSenha) {
      setState(() {
        _erroMensagem = 'A senha e a confirmação de senha devem ser iguais.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erroMensagem = null;
    });

    try {
      final Map<String, dynamic> payload = {
        'nome': nome,
        'email': email,
        'senha': senha,
      };
      if (celular.isNotEmpty) {
        payload['celular'] = celular;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/rpc/registra_usuario'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário cadastrado com sucesso! Faça seu login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(email);
      } else {
        final msg = extrairMensagemErro(
          response.body,
          'Erro ao cadastrar usuário (${response.statusCode}).',
        );
        setState(() {
          _erroMensagem = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroMensagem = 'Erro de conexão com o servidor: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Usuário'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Criar Nova Conta',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          hintText: 'Mínimo 3 caracteres',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'usuario@exemplo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _celularController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Celular',
                          hintText: '(21) 99999-9999',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          hintText: 'Mínimo 8 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultarSenha
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _ocultarSenha = !_ocultarSenha;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmarSenhaController,
                        obscureText: _ocultarConfirmacao,
                        decoration: InputDecoration(
                          labelText: 'Confirmação da Senha',
                          hintText: 'Repita a senha',
                          prefixIcon: const Icon(Icons.lock_reset),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultarConfirmacao
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _ocultarConfirmacao = !_ocultarConfirmacao;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (_) => _cadastrarUsuario(),
                      ),
                      if (_erroMensagem != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _erroMensagem!,
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _carregando ? null : _cadastrarUsuario,
                        icon: _carregando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _carregando ? 'Cadastrando...' : 'Cadastrar',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Voltar para o Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODELO E TELA DE LISTA DE TAREFAS
// ============================================================================

/// Modelo de dados de uma tarefa
class Tarefa {
  final String texto;
  bool concluida;
  bool pendenteExclusao;
  Timer? timerExclusao;

  Tarefa({
    required this.texto,
    this.concluida = false,
    this.pendenteExclusao = false,
    this.timerExclusao,
  });

  Map<String, dynamic> toJson(int ordem) {
    return {
      'titulo': texto,
      'concluida': concluida,
      'ordem': ordem,
    };
  }
}

class ListaTarefasScreen extends StatefulWidget {
  final String token;
  final String email;
  final String nome;

  const ListaTarefasScreen({
    super.key,
    required this.token,
    required this.email,
    required this.nome,
  });

  @override
  State<ListaTarefasScreen> createState() => _ListaTarefasScreenState();
}

class _ListaTarefasScreenState extends State<ListaTarefasScreen> {
  final List<Tarefa> _tarefas = [];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _carregando = true;
  bool _salvando = false;
  bool _listaExisteNoServidor = false;

  @override
  void initState() {
    super.initState();
    _carregarTarefasDoServidor();
  }

  @override
  void dispose() {
    for (final tarefa in _tarefas) {
      tarefa.timerExclusao?.cancel();
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Map<String, String> get _headersAutenticados => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json; charset=utf-8',
      };

  /// Trata expiração do token JWT (status 401) redirecionando para a tela de login
  void _tratarTokenExpirado() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          mensagemInicial:
              'Sua sessão expirou (o token vale 5 minutos). Faça login novamente.',
        ),
      ),
      (route) => false,
    );
  }

  /// Carrega a lista de tarefas armazenada na API (GET /tarefas)
  Future<void> _carregarTarefasDoServidor() async {
    setState(() {
      _carregando = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tarefas'),
        headers: _headersAutenticados,
      );

      if (!mounted) return;

      if (response.statusCode == 401) {
        _tratarTokenExpirado();
        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          for (final t in _tarefas) {
            t.timerExclusao?.cancel();
          }
          _tarefas.clear();

          if (decoded.isEmpty) {
            _listaExisteNoServidor = false;
          } else {
            _listaExisteNoServidor = true;
            final registro = decoded.first;
            final valor = registro is Map ? registro['valor'] : null;
            _preencherListaAPartirDoJson(valor);
          }
        }
      } else {
        final msg = extrairMensagemErro(
          response.body,
          'Erro ao carregar tarefas (${response.statusCode}).',
        );
        _mostrarMensagem(msg, Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensagem('Erro de conexão ao carregar: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  /// Converte o JSON do campo 'valor' da API para a lista de objetos Tarefa
  void _preencherListaAPartirDoJson(dynamic valor) {
    final List<Tarefa> naoConcluidas = [];
    final List<Tarefa> concluidas = [];

    if (valor is List) {
      final itens = List<dynamic>.from(valor);
      itens.sort((a, b) {
        final ordemA = (a is Map && a['ordem'] is num)
            ? (a['ordem'] as num).toInt()
            : 0;
        final ordemB = (b is Map && b['ordem'] is num)
            ? (b['ordem'] as num).toInt()
            : 0;
        return ordemA.compareTo(ordemB);
      });

      for (final item in itens) {
        if (item is Map) {
          final titulo =
              (item['titulo'] ?? item['texto'] ?? item['nome'] ?? '')
                  .toString()
                  .trim();
          if (titulo.isEmpty) continue;
          final concluida = item['concluida'] == true;
          if (concluida) {
            concluidas.add(Tarefa(texto: titulo, concluida: true));
          } else {
            naoConcluidas.add(Tarefa(texto: titulo, concluida: false));
          }
        }
      }
    } else if (valor is Map) {
      // Suporte caso o JSON esteja dividido em coleções
      final listaAtivas = valor['nao_concluidas'] ?? valor['ativas'] ?? [];
      final listaFeitas = valor['concluidas'] ?? [];
      if (listaAtivas is List) {
        for (final item in listaAtivas) {
          final titulo = item is Map
              ? (item['titulo'] ?? item['texto'] ?? '').toString().trim()
              : item.toString().trim();
          if (titulo.isNotEmpty) {
            naoConcluidas.add(Tarefa(texto: titulo, concluida: false));
          }
        }
      }
      if (listaFeitas is List) {
        for (final item in listaFeitas) {
          final titulo = item is Map
              ? (item['titulo'] ?? item['texto'] ?? '').toString().trim()
              : item.toString().trim();
          if (titulo.isNotEmpty) {
            concluidas.add(Tarefa(texto: titulo, concluida: true));
          }
        }
      }
    }

    _tarefas.addAll(naoConcluidas);
    _tarefas.addAll(concluidas);
  }

  /// Salva a lista atual de tarefas no servidor (POST na 1ª vez, PATCH nas demais)
  Future<void> _salvarTarefasNoServidor({bool mostrarFeedback = false}) async {
    if (!mounted) return;

    setState(() {
      _salvando = true;
    });

    final tarefasAtivas =
        _tarefas.where((t) => !t.pendenteExclusao).toList();
    final List<Map<String, dynamic>> valorJson = [
      for (int i = 0; i < tarefasAtivas.length; i++)
        tarefasAtivas[i].toJson(i + 1),
    ];

    try {
      http.Response response;

      if (!_listaExisteNoServidor) {
        response = await http.post(
          Uri.parse('$baseUrl/tarefas'),
          headers: _headersAutenticados,
          body: jsonEncode({
            'email': widget.email,
            'valor': valorJson,
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          _listaExisteNoServidor = true;
        } else if (response.statusCode == 409) {
          // A lista já existe no servidor: atualiza com PATCH
          _listaExisteNoServidor = true;
          response = await http.patch(
            Uri.parse('$baseUrl/tarefas?email=eq.${widget.email}'),
            headers: _headersAutenticados,
            body: jsonEncode({
              'valor': valorJson,
            }),
          );
        }
      } else {
        response = await http.patch(
          Uri.parse('$baseUrl/tarefas?email=eq.${widget.email}'),
          headers: {
            ..._headersAutenticados,
            'Prefer': 'return=representation',
          },
          body: jsonEncode({
            'valor': valorJson,
          }),
        );

        // Se a lista tinha sido apagada externamente (PATCH retornou []), cria com POST
        if (response.statusCode == 200 && response.body.trim() == '[]') {
          response = await http.post(
            Uri.parse('$baseUrl/tarefas'),
            headers: _headersAutenticados,
            body: jsonEncode({
              'email': widget.email,
              'valor': valorJson,
            }),
          );
          if (response.statusCode == 201 || response.statusCode == 200) {
            _listaExisteNoServidor = true;
          }
        }
      }

      if (!mounted) return;

      if (response.statusCode == 401) {
        _tratarTokenExpirado();
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mostrarFeedback) {
          _mostrarMensagem('Lista salva no servidor com sucesso!', Colors.green);
        }
      } else {
        final msg = extrairMensagemErro(
          response.body,
          'Erro ao salvar tarefas (${response.statusCode}).',
        );
        _mostrarMensagem(msg, Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensagem('Erro de conexão ao salvar: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  /// Adiciona uma nova tarefa à lista
  void _adicionarTarefa() {
    final texto = _controller.text.trim();

    if (texto.isEmpty) {
      _mostrarMensagem('A tarefa não pode ser vazia!', Colors.orange);
      return;
    }

    final existeDuplicada = _tarefas.any(
      (t) => t.texto.toLowerCase() == texto.toLowerCase(),
    );

    if (existeDuplicada) {
      _mostrarMensagem('Esta tarefa já existe na lista!', Colors.redAccent);
      return;
    }

    setState(() {
      final novaTarefa = Tarefa(texto: texto);
      final primeiroConcluidoIndex = _tarefas.indexWhere((t) => t.concluida);

      if (primeiroConcluidoIndex == -1) {
        _tarefas.add(novaTarefa);
      } else {
        _tarefas.insert(primeiroConcluidoIndex, novaTarefa);
      }

      _controller.clear();
    });

    _focusNode.requestFocus();
    _salvarTarefasNoServidor();
  }

  /// Alterna o estado de conclusão da tarefa
  void _alternarConclusao(Tarefa tarefa, bool? novoValor) {
    if (novoValor == null) return;

    setState(() {
      _tarefas.removeWhere((t) => t.texto == tarefa.texto);
      tarefa.concluida = novoValor;

      final primeiroConcluidoIndex = _tarefas.indexWhere((t) => t.concluida);
      if (primeiroConcluidoIndex == -1) {
        _tarefas.add(tarefa);
      } else {
        _tarefas.insert(primeiroConcluidoIndex, tarefa);
      }
    });

    _salvarTarefasNoServidor();
  }

  /// Inicia o processo de exclusão de 3 segundos
  void _iniciarExclusao(Tarefa tarefa) {
    if (tarefa.pendenteExclusao) return;

    setState(() {
      tarefa.pendenteExclusao = true;
    });

    tarefa.timerExclusao?.cancel();
    tarefa.timerExclusao = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _tarefas.removeWhere((t) => t.texto == tarefa.texto);
        });
        _salvarTarefasNoServidor();
      }
    });
  }

  /// Desfaz o processo de exclusão
  void _desfazerExclusao(Tarefa tarefa) {
    setState(() {
      tarefa.timerExclusao?.cancel();
      tarefa.timerExclusao = null;
      tarefa.pendenteExclusao = false;
    });
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _fazerLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Minhas Tarefas'),
            Text(
              widget.email,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Salvar lista no servidor',
            onPressed: _salvando
                ? null
                : () => _salvarTarefasNoServidor(mostrarFeedback: true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar do servidor',
            onPressed: _carregando ? null : _carregarTarefasDoServidor,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair (Logout)',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Barra de inclusão de tarefas
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nova Tarefa',
                        hintText: 'Digite e pressione Enter...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _adicionarTarefa(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _adicionarTarefa,
                    icon: const Icon(Icons.add),
                    label: const Text('Incluir'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Área da lista com relevo, borda e cor distinta da barra superior
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.indigo.shade200,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _carregando
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _tarefas.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhuma tarefa cadastrada.\nAdicione novas tarefas acima!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _tarefas.length,
                                itemBuilder: (context, index) {
                                  final tarefa = _tarefas[index];

                                  final Color corFundoItem =
                                      tarefa.pendenteExclusao
                                          ? Colors.red.shade100
                                          : (index.isEven
                                              ? Colors.white
                                              : const Color(0xFFE8EEF5));

                                  return Dismissible(
                                    key: ValueKey(tarefa.texto),
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade400,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Concluir',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    secondaryBackground: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Excluir',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        _iniciarExclusao(tarefa);
                                        return false;
                                      } else if (direction ==
                                          DismissDirection.startToEnd) {
                                        _alternarConclusao(
                                          tarefa,
                                          !tarefa.concluida,
                                        );
                                        return false;
                                      }
                                      return false;
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: corFundoItem,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: tarefa.pendenteExclusao
                                              ? Colors.red
                                              : Colors.black12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: tarefa.concluida,
                                            onChanged: tarefa.pendenteExclusao
                                                ? null
                                                : (valor) => _alternarConclusao(
                                                      tarefa,
                                                      valor,
                                                    ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              tarefa.texto,
                                              style: TextStyle(
                                                fontSize: 16,
                                                decoration: tarefa.concluida
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                                color: tarefa.pendenteExclusao
                                                    ? Colors.red.shade900
                                                    : (tarefa.concluida
                                                        ? Colors.grey.shade600
                                                        : Colors.black87),
                                                fontWeight: tarefa.concluida
                                                    ? FontWeight.normal
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (tarefa.pendenteExclusao)
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _desfazerExclusao(tarefa),
                                              icon: const Icon(
                                                Icons.undo,
                                                size: 18,
                                              ),
                                              label: const Text('Desfazer'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(
                                                  color: Colors.red,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              tooltip: 'Apagar tarefa',
                                              onPressed: () =>
                                                  _iniciarExclusao(tarefa),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando
                      ? null
                      : () => _salvarTarefasNoServidor(mostrarFeedback: true),
                  icon: _salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _salvando ? 'Salvando no servidor...' : 'Salvar Lista',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
