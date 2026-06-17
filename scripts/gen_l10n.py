#!/usr/bin/env python3
"""Génère App/Localizable.xcstrings (source fr) avec en, es, it, pt."""
import json

# clé fr -> {en, es, it, pt}
T = {
    "Aucun profil": ("No profile", "Sin perfiles", "Nessun profilo", "Nenhum perfil"),
    "Ajoutez un serveur SSH pour commencer.": ("Add an SSH server to get started.", "Añade un servidor SSH para empezar.", "Aggiungi un server SSH per iniziare.", "Adicione um servidor SSH para começar."),
    "Ajouter un profil": ("Add a profile", "Añadir un perfil", "Aggiungi un profilo", "Adicionar um perfil"),
    "Journaux": ("Logs", "Registros", "Log", "Registos"),
    "Supprimer": ("Delete", "Eliminar", "Elimina", "Eliminar"),
    "Modifier": ("Edit", "Editar", "Modifica", "Editar"),
    "Fichiers": ("Files", "Archivos", "File", "Ficheiros"),
    "Tunnel": ("Tunnel", "Túnel", "Tunnel", "Túnel"),
    "Erreur": ("Error", "Error", "Errore", "Erro"),
    "OK": ("OK", "OK", "OK", "OK"),
    "Annuler": ("Cancel", "Cancelar", "Annulla", "Cancelar"),
    "Enregistrer": ("Save", "Guardar", "Salva", "Guardar"),
    "Nouveau profil": ("New profile", "Nuevo perfil", "Nuovo profilo", "Novo perfil"),
    "Modifier le profil": ("Edit profile", "Editar perfil", "Modifica profilo", "Editar perfil"),
    "Serveur": ("Server", "Servidor", "Server", "Servidor"),
    "Authentification": ("Authentication", "Autenticación", "Autenticazione", "Autenticação"),
    "Méthode": ("Method", "Método", "Metodo", "Método"),
    "Mot de passe": ("Password", "Contraseña", "Password", "Palavra-passe"),
    "Clé privée": ("Private key", "Clave privada", "Chiave privata", "Chave privada"),
    "Port": ("Port", "Puerto", "Porta", "Porta"),
    "Utilisateur": ("User", "Usuario", "Utente", "Utilizador"),
    "Libellé (optionnel)": ("Label (optional)", "Etiqueta (opcional)", "Etichetta (facoltativa)", "Etiqueta (opcional)"),
    "Hôte ou IP": ("Host or IP", "Host o IP", "Host o IP", "Anfitrião ou IP"),
    "Générer une clé Ed25519": ("Generate an Ed25519 key", "Generar una clave Ed25519", "Genera una chiave Ed25519", "Gerar uma chave Ed25519"),
    "Copier la clé publique": ("Copy public key", "Copiar clave pública", "Copia chiave pubblica", "Copiar chave pública"),
    "Clé publique à installer sur le serveur": ("Public key to install on the server", "Clave pública para instalar en el servidor", "Chiave pubblica da installare sul server", "Chave pública para instalar no servidor"),
    "Jump host (ProxyJump)": ("Jump host (ProxyJump)", "Jump host (ProxyJump)", "Jump host (ProxyJump)", "Jump host (ProxyJump)"),
    "Passer par un rebond SSH": ("Connect through an SSH jump host", "Conectar a través de un salto SSH", "Connetti tramite un jump host SSH", "Ligar através de um jump host SSH"),
    "Hôte ou IP du rebond": ("Jump host or IP", "Salto: host o IP", "Jump host o IP", "Jump host ou IP"),
    "Secret du rebond": ("Jump host secret", "Secreto del salto", "Segreto del jump host", "Segredo do jump host"),
    "Phrase de passe (si chiffrée)": ("Passphrase (if encrypted)", "Frase de contraseña (si está cifrada)", "Passphrase (se cifrata)", "Frase-passe (se cifrada)"),
    "Clé hôte connue (TOFU)": ("Known host key (TOFU)", "Clave de host conocida (TOFU)", "Chiave host nota (TOFU)", "Chave de anfitrião conhecida (TOFU)"),
    "Réinitialiser la clé hôte connue": ("Reset known host key", "Restablecer clave de host conocida", "Reimposta chiave host nota", "Repor chave de anfitrião conhecida"),
    "Terminal": ("Terminal", "Terminal", "Terminale", "Terminal"),
    "Fermer": ("Close", "Cerrar", "Chiudi", "Fechar"),
    "Nouvel onglet": ("New tab", "Nueva pestaña", "Nuova scheda", "Novo separador"),
    "Nouvelle session": ("New session", "Nueva sesión", "Nuova sessione", "Nova sessão"),
    "Thème": ("Theme", "Tema", "Tema", "Tema"),
    "Thème du terminal": ("Terminal theme", "Tema del terminal", "Tema del terminale", "Tema do terminal"),
    "Connexion SFTP…": ("Connecting (SFTP)…", "Conectando (SFTP)…", "Connessione (SFTP)…", "A ligar (SFTP)…"),
    "Connexion impossible": ("Connection failed", "No se pudo conectar", "Connessione non riuscita", "Ligação falhou"),
    "Dossier vide": ("Empty folder", "Carpeta vacía", "Cartella vuota", "Pasta vazia"),
    "Envoyer un fichier": ("Upload a file", "Subir un archivo", "Carica un file", "Enviar um ficheiro"),
    "Nouveau dossier": ("New folder", "Nueva carpeta", "Nuova cartella", "Nova pasta"),
    "Créer": ("Create", "Crear", "Crea", "Criar"),
    "Nom": ("Name", "Nombre", "Nome", "Nome"),
    "Permissions": ("Permissions", "Permisos", "Permessi", "Permissões"),
    "Mode octal": ("Octal mode", "Modo octal", "Modalità ottale", "Modo octal"),
    "Préréglages": ("Presets", "Preajustes", "Preimpostazioni", "Predefinições"),
    "Appliquer": ("Apply", "Aplicar", "Applica", "Aplicar"),
    "Aucun journal": ("No logs", "Sin registros", "Nessun log", "Sem registos"),
    "Tout effacer": ("Clear all", "Borrar todo", "Cancella tutto", "Limpar tudo"),
    "Les sessions terminal et SFTP apparaîtront ici.": ("Terminal and SFTP sessions will appear here.", "Las sesiones de terminal y SFTP aparecerán aquí.", "Le sessioni terminale e SFTP appariranno qui.", "As sessões de terminal e SFTP aparecerão aqui."),
    "Démarrer le tunnel": ("Start tunnel", "Iniciar túnel", "Avvia tunnel", "Iniciar túnel"),
    "Arrêter": ("Stop", "Detener", "Ferma", "Parar"),
    "Réessayer": ("Retry", "Reintentar", "Riprova", "Tentar novamente"),
    "Connexion…": ("Connecting…", "Conectando…", "Connessione…", "A ligar…"),
    "Destination (vue depuis le serveur)": ("Destination (as seen from the server)", "Destino (visto desde el servidor)", "Destinazione (vista dal server)", "Destino (visto a partir do servidor)"),
    "Écoute locale": ("Local listener", "Escucha local", "Ascolto locale", "Escuta local"),
    "Hôte distant": ("Remote host", "Host remoto", "Host remoto", "Anfitrião remoto"),
    "Port distant": ("Remote port", "Puerto remoto", "Porta remota", "Porta remota"),
    "Port local (0 = auto)": ("Local port (0 = auto)", "Puerto local (0 = automático)", "Porta locale (0 = auto)", "Porta local (0 = automático)"),
    "Aucun secret enregistré pour ce profil.": ("No secret saved for this profile.", "No hay secreto guardado para este perfil.", "Nessun segreto salvato per questo profilo.", "Nenhum segredo guardado para este perfil."),
    # Onboarding
    "Bienvenue dans MaxiTerm": ("Welcome to MaxiTerm", "Bienvenido a MaxiTerm", "Benvenuto in MaxiTerm", "Bem-vindo ao MaxiTerm"),
    "100% gratuit, sans paywall": ("100% free, no paywall", "100% gratis, sin muro de pago", "100% gratuito, senza paywall", "100% grátis, sem paywall"),
    "Sécurisé et auditable": ("Secure and auditable", "Seguro y auditable", "Sicuro e verificabile", "Seguro e auditável"),
    "Prêt à commencer": ("Ready to start", "Listo para empezar", "Pronto per iniziare", "Pronto para começar"),
    "Continuer": ("Continue", "Continuar", "Continua", "Continuar"),
    "Commencer": ("Get started", "Empezar", "Inizia", "Começar"),
    # Tip jar
    "Soutenir": ("Support", "Apoyar", "Sostieni", "Apoiar"),
    "Offrir un pourboire": ("Leave a tip", "Dejar una propina", "Lascia una mancia", "Deixar uma gorjeta"),
    "Chargement…": ("Loading…", "Cargando…", "Caricamento…", "A carregar…"),
    "100% gratuit, sans abonnement": ("100% free, no subscription", "100% gratis, sin suscripción", "100% gratuito, senza abbonamento", "100% grátis, sem subscrição"),
    "Avec plaisir": ("You're welcome", "De nada", "Con piacere", "De nada"),
    "Votre soutien fait la différence.": ("Your support makes a difference.", "Tu apoyo marca la diferencia.", "Il tuo sostegno fa la differenza.", "O seu apoio faz a diferença."),
}

LANGS = ["en", "es", "it", "pt"]
strings = {}
for key, vals in T.items():
    locs = {}
    for lang, val in zip(LANGS, vals):
        locs[lang] = {"stringUnit": {"state": "translated", "value": val}}
    strings[key] = {"localizations": locs}

catalog = {"sourceLanguage": "fr", "version": "1.0", "strings": strings}
with open("App/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)
print(f"écrit {len(strings)} clés × {len(LANGS)} langues")
