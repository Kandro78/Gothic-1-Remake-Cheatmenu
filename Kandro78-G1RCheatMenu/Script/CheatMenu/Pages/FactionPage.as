// G1R Cheat Menu: Faction page. Enter makes the hero a member of that camp and rank, the same way
// the story does when someone takes him in (SetTrueGuild with the guild's gameplay effect).

struct FCMGuild
{
    FString Label;
    TSubclassOf<UGameplayEffect_Guild> Effect;
    FGameplayTag Tag;
}

class UCMFactionPage : UCMPage
{
    TArray<FCMGuild> Guilds;

    FString GetTitle() const override
    {
        return "Faction";
    }

    void AddGuild(FString Label, TSubclassOf<UGameplayEffect_Guild> Effect, FGameplayTag Tag)
    {
        FCMGuild guild;
        guild.Label = Label;
        guild.Effect = Effect;
        guild.Tag = Tag;
        Guilds.Add(guild);
    }

    // ordered by rank within a camp
    void Build(TArray<FCMItem>& Items) override
    {
        if (Guilds.Num() == 0)
        {
            AddGuild("No faction", UGE_Guild_None, GameplayTag::Guild_None);
            AddGuild("Old Camp: Digger", UGE_Guild_Human_OldCamp_Digger, GameplayTag::Guild_Human_OldCamp_Digger);
            AddGuild("Old Camp: Shadow", UGE_Guild_Human_OldCamp_Shadow, GameplayTag::Guild_Human_OldCamp_Shadow);
            AddGuild("Old Camp: Guard", UGE_Guild_Human_OldCamp_Guard, GameplayTag::Guild_Human_OldCamp_Guard);
            AddGuild("Old Camp: Fire Mage", UGE_Guild_Human_OldCamp_FireMage, GameplayTag::Guild_Human_OldCamp_FireMage);
            AddGuild("New Camp: Scraper", UGE_Guild_Human_NewCamp_Scraper, GameplayTag::Guild_Human_NewCamp_Scraper);
            AddGuild("New Camp: Peasant", UGE_Guild_Human_NewCamp_Peasant, GameplayTag::Guild_Human_NewCamp_Peasant);
            AddGuild("New Camp: Rogue", UGE_Guild_Human_NewCamp_Rogue, GameplayTag::Guild_Human_NewCamp_Rogue);
            AddGuild("New Camp: Mercenary", UGE_Guild_Human_NewCamp_Mercenary, GameplayTag::Guild_Human_NewCamp_Mercenary);
            AddGuild("New Camp: Water Mage", UGE_Guild_Human_NewCamp_WaterMage, GameplayTag::Guild_Human_NewCamp_WaterMage);
            AddGuild("Swamp Camp: Novice", UGE_Guild_Human_SwampCamp_Novice, GameplayTag::Guild_Human_SwampCamp_Novice);
            AddGuild("Swamp Camp: Templar", UGE_Guild_Human_SwampCamp_Templar, GameplayTag::Guild_Human_SwampCamp_Templar);
            AddGuild("Swamp Camp: Guru", UGE_Guild_Human_SwampCamp_Guru, GameplayTag::Guild_Human_SwampCamp_Guru);
        }
        for (int i = 0; i < Guilds.Num(); i++)
            Items.Add(CM::Item(Guilds[i].Label, ECMKind::Action, FName("Guild" + i)));
    }

    int GuildIndex(FName Id)
    {
        FString s = Id.ToString();
        if (!s.StartsWith("Guild"))
            return -1;
        int i = String::Conv_StringToInt(s.RightChop(5));
        return i < Guilds.Num() ? i : -1;
    }

    AGothicCharacterState HeroState()
    {
        AGothicCharacter hero = CM::Hero();
        return hero != nullptr ? hero.GetCharacterState() : nullptr;
    }

    FString GetValue(FName Id) override
    {
        int i = GuildIndex(Id);
        AGothicCharacterState state = HeroState();
        if (i < 0 || state == nullptr)
            return "";
        return state.IsTrulyPartOfGuild(Guilds[i].Tag) ? "current" : "";
    }

    FString Activate(FName Id, int Dir) override
    {
        int i = GuildIndex(Id);
        if (i < 0)
            return "";
        AGothicCharacterState state = HeroState();
        if (state == nullptr)
            return CM::NotInGame;
        state.SetTrueGuild(Guilds[i].Effect);
        if (!state.IsTrulyPartOfGuild(Guilds[i].Tag))
            return "Faction change failed";
        return i == 0 ? "Faction removed" : CM::F("Faction set: {0}", Guilds[i].Label);
    }
}
