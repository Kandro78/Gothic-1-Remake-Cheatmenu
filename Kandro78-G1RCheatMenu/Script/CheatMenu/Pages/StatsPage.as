// G1R Cheat Menu: Stats page. Left / Right change a stat by its step times the step multiplier.
// Strength, dexterity and max mana go through the game's own increase effects (as a teacher does),
// experience through GiveExperience (so level-ups and learning points follow); the rest are set
// on the attribute directly.

struct FCMStat
{
    FString Label;
    TSubclassOf<UAngelscriptAttributeSet> Set;
    FName Field;
    float Step;
    FName Also;      // set to the same value too (current health / mana with their maximum)
    float Min = 0;
    int Increase = 0; // 1 strength, 2 dexterity, 3 max mana, 4 experience
}

class UCMStatsPage : UCMPage
{
    TArray<FCMStat> Stats;
    int Mult = 1;
    const int MaxTrained = 100; // the most a teacher trains strength, dexterity and max mana to

    FString GetTitle() const override
    {
        return "Stats";
    }

    void AddStat(FString Label, TSubclassOf<UAngelscriptAttributeSet> Set, FName Field, float Step,
                 int Increase = 0, FName Also = NAME_None, float Min = 0)
    {
        FCMStat stat;
        stat.Label = Label;
        stat.Set = Set;
        stat.Field = Field;
        stat.Step = Step;
        stat.Increase = Increase;
        stat.Also = Also;
        stat.Min = Min;
        Stats.Add(stat);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Stats.Num() == 0)
        {
            AddStat("Strength", UAttributeSet_Strength, n"Strength", 5, 1);
            AddStat("Dexterity", UAttributeSet_Dexterity, n"Dexterity", 5, 2);
            AddStat("Max mana", UAttributeSet_Mana, n"MaxMana", 5, 3, n"Mana");
            AddStat("Max health", UAttributeSet_Health, n"MaxHealth", 10, 0, n"Health", 1);
            AddStat("Learning points", UAttributeSet_LevelProgression, n"Skillpoints", 5);
            AddStat("Level", UAttributeSet_LevelProgression, n"Level", 1);
            AddStat("Experience", UAttributeSet_LevelProgression, n"Experience", 500, 4);
        }
        Items.Add(CM::Item(CM::F("Strength, dexterity, max mana to {0}", "" + MaxTrained), ECMKind::Action, n"Max"));
        Items.Add(CM::Item("Step multiplier", ECMKind::Value, n"Mult"));
        for (int i = 0; i < Stats.Num(); i++)
            Items.Add(CM::Item(Stats[i].Label, ECMKind::Value, FName("Stat" + i)));
    }

    int StatIndex(FName Id)
    {
        FString s = Id.ToString();
        if (!s.StartsWith("Stat"))
            return -1;
        return String::Conv_StringToInt(s.RightChop(4));
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"Mult")
            return "x" + Mult;
        int i = StatIndex(Id);
        if (i < 0 || i >= Stats.Num())
            return "";
        float value = CM::Attr(Stats[i].Set, Stats[i].Field);
        return value < 0 ? "-" : CM::Num(value);
    }

    FString Activate(FName Id, int Dir) override
    {
        if (Id == n"Mult")
        {
            TArray<int> steps;
            steps.Add(1);
            steps.Add(2);
            steps.Add(10);
            int idx = Math::Max(steps.FindIndex(Mult), 0);
            Mult = steps[Math::Clamp(idx + Dir, 0, steps.Num() - 1)];
            return CM::F("Step multiplier x{0}", "" + Mult);
        }
        AGothicCharacter hero = CM::Hero();
        if (hero == nullptr)
            return CM::NotInGame;
        if (Id == n"Max")
            return MaxStats(hero);
        int i = StatIndex(Id);
        if (i < 0 || i >= Stats.Num())
            return "";
        return Change(hero, Stats[i], Dir * Stats[i].Step * Mult);
    }

    FString Change(AGothicCharacter Hero, FCMStat Stat, float Delta)
    {
        AGothicCharacterState state = Hero.GetCharacterState();
        float cur = CM::Attr(Stat.Set, Stat.Field);
        if (state == nullptr || cur < 0)
            return CM::F("{0}: value not found", Stat.Label);
        float target = Math::Max(Stat.Min, cur + Delta);
        float delta = target - cur;
        if (delta == 0)
            return CM::T(Stat.Label) + ": " + CM::Num(cur);

        if (Stat.Increase == 1)
            state.IncreaseStrengthAttributeBy(delta);
        else if (Stat.Increase == 2)
            state.IncreaseDexterityAttributeBy(delta);
        else if (Stat.Increase == 3)
            state.IncreaseMaxManaAttributeBy(delta);
        else if (Stat.Increase == 4)
        {
            if (delta < 0)
                return "Experience can only be increased";
            state.GiveExperience(Math::RoundToInt(delta));
        }
        else if (!CM::SetAttr(Stat.Set, Stat.Field, target))
            return CM::F("{0}: change failed", Stat.Label);
        if (Stat.Also != NAME_None)
            CM::SetAttr(Stat.Set, Stat.Also, CM::Attr(Stat.Set, Stat.Field));
        return CM::T(Stat.Label) + ": " + CM::Num(cur) + " -> " + CM::Num(CM::Attr(Stat.Set, Stat.Field));
    }

    // strength, dexterity and max mana up to MaxTrained; a value already higher is left alone
    FString MaxStats(AGothicCharacter Hero)
    {
        int raised = 0;
        for (FCMStat stat : Stats)
        {
            if (stat.Increase < 1 || stat.Increase > 3)
                continue;
            float cur = CM::Attr(stat.Set, stat.Field);
            if (cur >= 0 && cur < MaxTrained)
            {
                Change(Hero, stat, MaxTrained - cur);
                raised++;
            }
        }
        return CM::F("Raised {0} stat(s) to {1}", "" + raised, "" + MaxTrained);
    }
}
