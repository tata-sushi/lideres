<?php
/**
 * Proxy PHP — Anthropic API
 *
 * Versão pra hospedagem compartilhada (Hostinger, HostGator, Locaweb, etc.)
 * que suporta PHP 7.4+ com cURL habilitado (padrão na maioria).
 *
 * Deploy:
 *   1. Defina a constante ANTHROPIC_API_KEY abaixo OU crie um arquivo
 *      .env na mesma pasta com: ANTHROPIC_API_KEY=sk-ant-xxxx
 *      (a segunda opção é mais segura pois não vaza no Git)
 *   2. Faça upload deste arquivo para /public_html/api/sancao.php
 *      (ou qualquer outro caminho) via File Manager do Hostinger ou FTP
 *   3. Ajuste AI_PROXY_URL no front pra apontar pra cá
 *
 * Endpoint final: https://<seu-dominio>/api/sancao.php
 */

// ═══════════════════════════════════════════════
// CONFIGURAÇÃO
// ═══════════════════════════════════════════════

// Opção A — chave direto aqui (menos seguro, não commitar no git):
// define('ANTHROPIC_API_KEY', 'sk-ant-xxxxxxxxxxxx');

// Opção B — chave via arquivo .env (recomendado):
function load_env_key() {
    $envFile = __DIR__ . '/.env';
    if (!is_file($envFile)) return null;
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        if (strpos($line, 'ANTHROPIC_API_KEY=') === 0) {
            return trim(substr($line, strlen('ANTHROPIC_API_KEY=')), " \t\n\r\0\x0B\"'");
        }
    }
    return null;
}

$API_KEY = defined('ANTHROPIC_API_KEY') ? ANTHROPIC_API_KEY : load_env_key();

// Origens permitidas (CORS + validação). Adicione domínios conforme precisar.
$ALLOWED_ORIGINS = [
    'https://lideres.tatasushi.tech',
    'http://localhost:8080',   // para testes locais — remover em produção
];

// Modelos permitidos
$ALLOWED_MODELS = [
    'claude-sonnet-4-5',
    'claude-opus-4-6',
    'claude-haiku-4-5-20251001',
];

// Rate limit: 30 requisições por hora por IP
$RATE_LIMIT       = 30;
$RATE_WINDOW_SEC  = 3600;
$RATE_DIR         = sys_get_temp_dir() . '/lideres_rate';

// Limite de tokens
$MAX_TOKENS_CAP = 2000;

// ═══════════════════════════════════════════════
// CORS + HEADERS
// ═══════════════════════════════════════════════

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed_origin = in_array($origin, $ALLOWED_ORIGINS, true) ? $origin : '';

header('Content-Type: application/json; charset=utf-8');
header('Vary: Origin');
if ($allowed_origin) {
    header('Access-Control-Allow-Origin: ' . $allowed_origin);
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    header('Access-Control-Max-Age: 86400');
}

// Preflight CORS
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Só aceita POST
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Método não permitido']);
    exit;
}

// Valida origem (defesa extra além do CORS)
if (!$allowed_origin) {
    http_response_code(403);
    echo json_encode(['error' => 'Origem não autorizada']);
    exit;
}

// Chave configurada?
if (!$API_KEY) {
    http_response_code(500);
    echo json_encode(['error' => 'Servidor não configurado: ANTHROPIC_API_KEY ausente']);
    exit;
}

// ═══════════════════════════════════════════════
// RATE LIMIT POR IP (baseado em arquivo)
// ═══════════════════════════════════════════════

$ip = $_SERVER['HTTP_CF_CONNECTING_IP']
    ?? $_SERVER['HTTP_X_FORWARDED_FOR']
    ?? $_SERVER['REMOTE_ADDR']
    ?? 'unknown';
$ip = preg_replace('/[^0-9a-fA-F:.]/', '', explode(',', $ip)[0]);

if (!is_dir($RATE_DIR)) { @mkdir($RATE_DIR, 0700, true); }
$rateFile = $RATE_DIR . '/' . md5($ip) . '.json';

$now = time();
$timestamps = [];
if (is_file($rateFile)) {
    $data = @json_decode(file_get_contents($rateFile), true);
    if (is_array($data)) {
        $timestamps = array_filter($data, fn($t) => ($now - $t) < $RATE_WINDOW_SEC);
    }
}

if (count($timestamps) >= $RATE_LIMIT) {
    $oldest = min($timestamps);
    $retryIn = ceil(($RATE_WINDOW_SEC - ($now - $oldest)) / 60);
    http_response_code(429);
    header('Retry-After: ' . ($retryIn * 60));
    echo json_encode(['error' => "Rate limit excedido. Tente novamente em {$retryIn} min."]);
    exit;
}

$timestamps[] = $now;
@file_put_contents($rateFile, json_encode(array_values($timestamps)));

// ═══════════════════════════════════════════════
// PAYLOAD
// ═══════════════════════════════════════════════

$raw = file_get_contents('php://input');
$payload = json_decode($raw, true);
if (!is_array($payload)) {
    http_response_code(400);
    echo json_encode(['error' => 'JSON inválido']);
    exit;
}

$model = $payload['model'] ?? 'claude-sonnet-4-5';
if (!in_array($model, $ALLOWED_MODELS, true)) {
    http_response_code(400);
    echo json_encode(['error' => "Modelo não permitido: {$model}"]);
    exit;
}

$maxTokens = min((int)($payload['max_tokens'] ?? 1000), $MAX_TOKENS_CAP);
$messages  = $payload['messages'] ?? null;
if (!is_array($messages) || count($messages) === 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Campo "messages" obrigatório']);
    exit;
}

// ═══════════════════════════════════════════════
// ENCAMINHA PRA ANTHROPIC
// ═══════════════════════════════════════════════

$ch = curl_init('https://api.anthropic.com/v1/messages');
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST           => true,
    CURLOPT_HTTPHEADER     => [
        'Content-Type: application/json',
        'x-api-key: ' . $API_KEY,
        'anthropic-version: 2023-06-01',
    ],
    CURLOPT_POSTFIELDS     => json_encode([
        'model'      => $model,
        'max_tokens' => $maxTokens,
        'messages'   => $messages,
    ]),
    CURLOPT_TIMEOUT        => 60,
    CURLOPT_CONNECTTIMEOUT => 10,
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErr  = curl_error($ch);
curl_close($ch);

if ($response === false) {
    http_response_code(502);
    echo json_encode(['error' => 'Falha ao contatar Anthropic: ' . $curlErr]);
    exit;
}

http_response_code($httpCode ?: 200);
echo $response;
