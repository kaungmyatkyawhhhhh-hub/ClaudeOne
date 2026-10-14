-- DNA Tokens (owner, 14 Oct): a token pays for one genetics reroll. There are ONLY three ways to get one:
--   1. Free: +1 for every Growth Spurt (PlayerData.GrowthSpurt, once per spurt, on the server).
--   2. Coins: CoinPrice coins for 1 token, in the Shop (Items) and on the Genetics screen (REROLL with no tokens).
--   3. Robux: the developer product Config.Products.DNAToken (MonetizationService, granted once per purchase id).
-- Nothing else gives tokens (no daily rewards, quests, legends, codes or starting tokens). Tokens never go below 0.
local DNA = {}

DNA.CoinPrice = 25000
DNA.PerGrowthSpurt = 1
DNA.RobuxPrice = 99 -- shown until Roblox's real price for the product has loaded

return DNA
