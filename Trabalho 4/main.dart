import 'dart:convert';
import 'dart:io';

const String baseUrl = 'https://barra.cos.ufrj.br/rest';
const String nome = 'Pedro Ivo Lopes Pinheiro';
const String email = 'pedroivolpinheiro@gmail.com';
const String senha = 'SenhaSegura123!';

Future<void> main() async {
  final client = HttpClient();

  try {
    // 1. Cadastrar o usuário
    final regReq = await client.postUrl(
      Uri.parse('$baseUrl/rpc/registra_usuario'),
    );
    regReq.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    regReq.add(
      utf8.encode(
        jsonEncode({
          'nome': nome,
          'email': email,
          'senha': senha,
        }),
      ),
    );
    final regRes = await regReq.close();
    final regBody = await regRes.transform(utf8.decoder).join();

    if (regRes.statusCode != 200 && regRes.statusCode != 201) {
      bool emailEmUso = false;
      if (regRes.statusCode == 400) {
        try {
          final erro = jsonDecode(regBody);
          if (erro is Map &&
              erro['message'] != null &&
              erro['message'].toString().contains('O email já está em uso')) {
            emailEmUso = true;
          }
        } catch (_) {
          if (regBody.contains('O email já está em uso')) {
            emailEmUso = true;
          }
        }
      }
      if (!emailEmUso) {
        stderr.writeln(
          'Erro ao cadastrar usuário (${regRes.statusCode}): $regBody',
        );
        exit(1);
      }
    }

    // Aguarda 1 segundo para garantir que o timestamp (exp em segundos) do JWT
    // gerado pelo banco seja diferente entre duas execuções rápidas seguidas.
    await Future.delayed(const Duration(seconds: 1));

    // 2. Fazer login e obter o token JWT
    final loginReq = await client.postUrl(
      Uri.parse('$baseUrl/rpc/fazer_login'),
    );
    loginReq.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    loginReq.add(
      utf8.encode(
        jsonEncode({
          'email': email,
          'senha': senha,
        }),
      ),
    );
    final loginRes = await loginReq.close();
    final loginBody = await loginRes.transform(utf8.decoder).join();

    if (loginRes.statusCode != 200) {
      stderr.writeln('Erro ao fazer login (${loginRes.statusCode}): $loginBody');
      exit(1);
    }

    final loginData = jsonDecode(loginBody);
    final String? token =
        loginData is Map ? loginData['token']?.toString() : null;
    if (token == null || token.isEmpty) {
      stderr.writeln('Erro: token JWT não encontrado na resposta do login.');
      exit(1);
    }

    // 3. Consultar a lista de tarefas
    final getReq = await client.getUrl(Uri.parse('$baseUrl/tarefas'));
    getReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final getRes = await getReq.close();
    final getBody = await getRes.transform(utf8.decoder).join();

    if (getRes.statusCode != 200) {
      stderr.writeln(
        'Erro ao consultar tarefas (${getRes.statusCode}): $getBody',
      );
      exit(1);
    }

    final tarefas = jsonDecode(getBody);
    if (tarefas is! List) {
      stderr.writeln('Erro: formato inesperado ao consultar tarefas: $getBody');
      exit(1);
    }

    // 4. Garantir que a lista de tarefas exista e esteja vazia
    if (tarefas.isEmpty) {
      final postReq = await client.postUrl(Uri.parse('$baseUrl/tarefas'));
      postReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      postReq.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      postReq.add(
        utf8.encode(
          jsonEncode({
            'email': email,
            'valor': [],
          }),
        ),
      );
      final postRes = await postReq.close();
      final postBody = await postRes.transform(utf8.decoder).join();

      if (postRes.statusCode < 200 || postRes.statusCode >= 300) {
        stderr.writeln(
          'Erro ao criar lista de tarefas (${postRes.statusCode}): $postBody',
        );
        exit(1);
      }
    } else {
      final patchReq = await client.patchUrl(
        Uri.parse('$baseUrl/tarefas?email=eq.$email'),
      );
      patchReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      patchReq.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      patchReq.add(
        utf8.encode(
          jsonEncode({
            'valor': [],
          }),
        ),
      );
      final patchRes = await patchReq.close();
      final patchBody = await patchRes.transform(utf8.decoder).join();

      if (patchRes.statusCode < 200 || patchRes.statusCode >= 300) {
        stderr.writeln(
          'Erro ao esvaziar lista de tarefas (${patchRes.statusCode}): $patchBody',
        );
        exit(1);
      }
    }

    // 5. Imprimir apenas o token JWT na saída padrão
    print(token.trim());
  } catch (e) {
    stderr.writeln('Erro inesperado: $e');
    exit(1);
  } finally {
    client.close();
  }
}

