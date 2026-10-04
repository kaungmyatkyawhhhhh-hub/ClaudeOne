"""
Steal An Egg Notifier bot
-------------------------
Posts "Secret Egg Spawned!!" alerts (embed + role ping + Join Game link) to every
server that has run /setup.

Spawns come in two ways:
  1. /spawn slash command  (only users listed in REPORTER_IDS can use it)
  2. HTTP POST to http://<host>:<API_PORT>/spawn with header X-API-Key  (for any feed you hook up)

Each rarity can ping its own role: /setrole rarity:Divine role:@Divine Egg
Rarities without their own role ping the role chosen in /setup.
"""

import json
import os
import re
import time
from pathlib import Path

import discord
from aiohttp import web
from discord import app_commands
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / "settings.txt")

TOKEN = os.getenv("DISCORD_TOKEN", "")
PLACE_ID = os.getenv("PLACE_ID", "")  # Steal An Egg place id (from the game's roblox.com URL)
API_KEY = os.getenv("API_KEY", "")
API_PORT = int(os.getenv("API_PORT", "8080"))
INVITE_URL = os.getenv("INVITE_URL", "")
BOT_NAME = os.getenv("BOT_NAME", "Egg Notifier")
REPORTER_IDS = {int(x) for x in os.getenv("REPORTER_IDS", "").replace(" ", "").split(",") if x}
DEDUPE_MINUTES = int(os.getenv("DEDUPE_MINUTES", "10"))
# Channel where SenZ (or another notifier) posts — the bot copies those alerts in its own style
SOURCE_CHANNEL_ID = int(os.getenv("SOURCE_CHANNEL_ID", "0") or 0)

BASE = Path(__file__).parent
EGGS_FILE = BASE / "eggs.json"
GUILDS_FILE = BASE / "guilds.json"

RARITIES = ["Secret", "Eternal", "Divine"]


# ---------- data helpers ----------
def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def save_json(path: Path, data):
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


EGG_DATA = load_json(EGGS_FILE, {"eggs": {}, "locations": {}})
# {guild_id: {"channel": id, "role": id|None, "rarity_roles": {"divine": id, ...}}}
guild_config: dict = load_json(GUILDS_FILE, {})
recent: dict = {}  # dedupe: (egg, job_id) -> unix time


def find_egg(name: str):
    for key, info in EGG_DATA["eggs"].items():
        if key.lower() == name.lower():
            return key, info
    return name, {}


def spawn_rarity(spawn: dict) -> str:
    """Rarity from the report, else from eggs.json, else Secret."""
    _, info = find_egg(spawn["egg"])
    return spawn.get("rarity") or info.get("rarity") or "Secret"


def join_url(job_id: str | None) -> str:
    if PLACE_ID and job_id:
        return f"https://www.roblox.com/games/start?placeId={PLACE_ID}&gameInstanceId={job_id}"
    if PLACE_ID:
        return f"https://www.roblox.com/games/{PLACE_ID}"
    return "https://www.roblox.com"


# ---------- embed ----------
def build_alert(spawn: dict) -> tuple[discord.Embed, str]:
    egg, info = find_egg(spawn["egg"])
    location = spawn.get("location", "Unknown")
    loc_emoji = EGG_DATA["locations"].get(location, "📍")
    rarity = spawn_rarity(spawn)
    money = spawn.get("money") or info.get("money", "?")
    speed = spawn.get("speed") or info.get("speed", "?")
    minutes_ago = int(spawn.get("minutes_ago", 0) or 0)

    now = int(time.time())
    spawned_at = int(spawn.get("spawned_at") or now - minutes_ago * 60)
    link = spawn.get("join_url") or join_url(spawn.get("job_id"))

    desc = (
        f"### 🥚 {rarity} Egg Spawned!! - <t:{now}:t>\n"
        f"🥚 **Egg:** {egg}\n"
        f"{loc_emoji} **Location:** {location}\n"
        f"⏱️ **Spawned:** <t:{spawned_at}:R>\n"
        f"💸 **Money:** {money}\n"
        f"👟 **Recommended Speed:** {speed}\n"
        f"🎮 **Join Game:** [Click Here]({link})"
    )
    embed = discord.Embed(description=desc, color=0x2B2D31)
    image = info.get("image") or spawn.get("image")
    if image:
        embed.set_thumbnail(url=image)
    embed.set_footer(text=f"{BOT_NAME} | Steal An Egg Notifier")
    return embed, f"{egg} spawned in {location}!"


class InviteView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)
        if INVITE_URL:
            self.add_item(discord.ui.Button(label="Add me to your server", emoji="🔗", url=INVITE_URL))


# ---------- bot ----------
intents = discord.Intents.default()
intents.message_content = True  # needed to read SenZ's alerts
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)


async def broadcast(spawn: dict) -> int:
    """Send the alert to every configured server. Returns how many got it."""
    key = (spawn["egg"].lower(), spawn.get("job_id") or spawn.get("location", ""))
    if time.time() - recent.get(key, 0) < DEDUPE_MINUTES * 60:
        return 0
    recent[key] = time.time()

    embed, line = build_alert(spawn)
    rarity = spawn_rarity(spawn).lower()
    sent = 0
    for gid, cfg in list(guild_config.items()):
        channel = client.get_channel(int(cfg["channel"]))
        if channel is None:
            continue
        role = cfg.get("rarity_roles", {}).get(rarity) or cfg.get("role")
        ping = f"<@&{role}> " if role else ""
        try:
            await channel.send(
                content=ping + line,
                embed=embed,
                view=InviteView(),
                allowed_mentions=discord.AllowedMentions(roles=True),
            )
            sent += 1
        except discord.HTTPException as e:
            print(f"[warn] couldn't post in guild {gid}: {e}")
    return sent


@tree.command(name="setup", description="Choose the channel (and role to ping) for egg alerts")
@app_commands.default_permissions(manage_guild=True)
@app_commands.describe(channel="Where alerts go", role="Role to ping (e.g. @Secret Egg)")
async def setup_cmd(inter: discord.Interaction, channel: discord.TextChannel, role: discord.Role | None = None):
    old = guild_config.get(str(inter.guild_id), {})
    guild_config[str(inter.guild_id)] = {
        "channel": channel.id,
        "role": role.id if role else None,
        "rarity_roles": old.get("rarity_roles", {}),
    }
    save_json(GUILDS_FILE, guild_config)
    await inter.response.send_message(
        f"✅ Alerts will post in {channel.mention}" + (f" and ping {role.mention}" if role else ""),
        ephemeral=True,
    )


@tree.command(name="setrole", description="Pick which role gets pinged for one egg rarity")
@app_commands.default_permissions(manage_guild=True)
@app_commands.describe(rarity="Egg rarity", role="Role to ping for that rarity (leave empty to clear)")
@app_commands.choices(rarity=[app_commands.Choice(name=r, value=r.lower()) for r in RARITIES])
async def setrole_cmd(inter: discord.Interaction, rarity: app_commands.Choice[str], role: discord.Role | None = None):
    cfg = guild_config.get(str(inter.guild_id))
    if not cfg:
        return await inter.response.send_message("⚠️ Run /setup first.", ephemeral=True)
    roles = cfg.setdefault("rarity_roles", {})
    if role:
        roles[rarity.value] = role.id
    else:
        roles.pop(rarity.value, None)
    save_json(GUILDS_FILE, guild_config)
    await inter.response.send_message(
        f"✅ {rarity.name} eggs will ping {role.mention}." if role
        else f"✅ {rarity.name} eggs will ping the /setup role.",
        ephemeral=True,
    )


@tree.command(name="disable", description="Stop egg alerts in this server")
@app_commands.default_permissions(manage_guild=True)
async def disable_cmd(inter: discord.Interaction):
    guild_config.pop(str(inter.guild_id), None)
    save_json(GUILDS_FILE, guild_config)
    await inter.response.send_message("🛑 Egg alerts disabled here.", ephemeral=True)


async def egg_autocomplete(_: discord.Interaction, current: str):
    return [app_commands.Choice(name=n, value=n) for n in EGG_DATA["eggs"] if current.lower() in n.lower()][:25]


async def loc_autocomplete(_: discord.Interaction, current: str):
    return [app_commands.Choice(name=n, value=n) for n in EGG_DATA["locations"] if current.lower() in n.lower()][:25]


@tree.command(name="spawn", description="Report an egg spawn (reporters only)")
@app_commands.describe(
    egg="Egg name", location="Where it spawned", job_id="Server JobId for the Join link (optional)",
    minutes_ago="How long ago it spawned", money="Override money/s", speed="Override recommended speed",
    rarity="Override rarity (otherwise taken from eggs.json)",
)
@app_commands.autocomplete(egg=egg_autocomplete, location=loc_autocomplete)
@app_commands.choices(rarity=[app_commands.Choice(name=r, value=r) for r in RARITIES])
async def spawn_cmd(
    inter: discord.Interaction, egg: str, location: str, job_id: str | None = None,
    minutes_ago: int = 0, money: str | None = None, speed: str | None = None,
    rarity: app_commands.Choice[str] | None = None,
):
    if inter.user.id not in REPORTER_IDS:
        return await inter.response.send_message("❌ You're not a reporter.", ephemeral=True)
    await inter.response.defer(ephemeral=True)
    n = await broadcast({"egg": egg, "location": location, "job_id": job_id,
                         "minutes_ago": minutes_ago, "money": money, "speed": speed,
                         "rarity": rarity.value if rarity else None})
    await inter.followup.send(f"📣 Sent to {n} server(s)." if n else "⚠️ Duplicate or no servers set up.", ephemeral=True)


# ---------- copy alerts from SenZ ----------
def parse_notifier_embed(embed: discord.Embed) -> dict | None:
    parts = [embed.title or "", embed.description or ""]
    parts += [f"{f.name}: {f.value}" for f in embed.fields]
    text = "\n".join(parts)
    plain = re.sub(r"<a?:\w+:\d+>", "", text).replace("*", "")  # drop custom emojis + bold

    def grab(label):
        m = re.search(label + r"\s*:\s*(.+)", plain, re.I)
        return m.group(1).strip() if m else None

    egg, location = grab("Egg"), grab("Location")
    if not egg or not location:
        return None
    # Look for a known rarity word anywhere in the alert (title, description, fields)
    rarity = re.search(r"\b(" + "|".join(RARITIES) + r")\b", plain, re.I)
    ts = re.search(r"Spawned\s*:.*?<t:(\d+)", plain, re.I)
    link = re.search(r"\((https?://[^)\s]*roblox[^)\s]*)\)", text) or re.search(r"https?://\S*roblox\S*", text)
    return {
        "egg": egg, "location": location,
        "rarity": rarity.group(1).capitalize() if rarity else None,
        "money": grab("Money"), "speed": grab("Recommended Speed"),
        "spawned_at": int(ts.group(1)) if ts else None,
        "join_url": (link.group(1) if link and link.lastindex else link.group(0)) if link else None,
        "image": embed.thumbnail.url if embed.thumbnail else None,
    }


@client.event
async def on_message(message: discord.Message):
    if not SOURCE_CHANNEL_ID or message.channel.id != SOURCE_CHANNEL_ID:
        return
    if message.author == client.user or not message.embeds:
        return
    for emb in message.embeds:
        spawn = parse_notifier_embed(emb)
        if spawn:
            n = await broadcast(spawn)
            print(f"[copy] {spawn['rarity']} {spawn['egg']} in {spawn['location']} -> {n} server(s)")


# ---------- HTTP API ----------
async def http_spawn(request: web.Request):
    if not API_KEY or request.headers.get("X-API-Key") != API_KEY:
        return web.json_response({"error": "unauthorized"}, status=401)
    try:
        data = await request.json()
        assert data.get("egg") and data.get("location")
    except Exception:
        return web.json_response({"error": "need JSON with 'egg' and 'location'"}, status=400)
    n = await broadcast(data)
    return web.json_response({"sent_to": n})


async def start_api():
    app = web.Application()
    app.router.add_post("/spawn", http_spawn)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", API_PORT).start()
    print(f"[api] listening on :{API_PORT}/spawn")


@client.event
async def setup_hook():
    await tree.sync()
    if API_KEY:
        await start_api()


@client.event
async def on_ready():
    print(f"[bot] logged in as {client.user} — in {len(client.guilds)} server(s)")


if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("Put your DISCORD_TOKEN in settings.txt first.")
    client.run(TOKEN)
