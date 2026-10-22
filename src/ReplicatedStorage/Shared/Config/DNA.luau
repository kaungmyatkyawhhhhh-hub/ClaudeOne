-- DNA Tokens (owner, 14 Oct): a token pays for one genetics reroll. These are the ONLY ways to get one (all on the
-- server; keep every one of them):
--   1. Free: +1 for every Growth Spurt (PlayerData.GrowthSpurt, once per spurt).
--   2. Free: the daily login calendar, +1 on day 4 and +1 on day 7 (Config/Economy.Login.DnaTokens, DailyService).
--   3. Coins: CoinPrice coins for 1 token, in the Shop (Items) and on the Genetics screen (REROLL with no tokens).
--   4. Robux: the developer product Config.Products.DNAToken (MonetizationService, granted once per purchase id), and
--      (prompt 60) the DNA TOKEN x3 product and the one-time STARTER PACK (1 token).
-- Nothing else gives tokens (no quests, legends, codes or starting tokens). Tokens never go below 0.
local DNA = {}

DNA.CoinPrice = 25000
DNA.PerGrowthSpurt = 1
DNA.RobuxPrice = 99 -- shown until Roblox's real price for the product has loaded
-- (prompt 60) what a token does, in one line on every card that sells one (kids should know what they're buying)
DNA.TokenLine = "A DNA token pays for one genetics reroll."

return DNA
