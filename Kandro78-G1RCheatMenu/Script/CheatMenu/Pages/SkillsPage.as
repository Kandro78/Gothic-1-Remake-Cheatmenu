// G1R Cheat Menu: Skills page. Enter / Right learns a skill for free, Left removes it.
// Free training: a skill's price sits on the defaults of its effect class (m_SPCost learning points,
// OreCost ore), which the teachers read; while on, both are 0 for every skill. Stat training is paid
// in learning points only, so while on, any drop in them is undone (a raise is kept).

// Lasts for the whole game session in its class default object, like UCMPlayerState
class UCMSkillState : UObject
{
    bool bTrain = false;
    bool bPricesRead = false;
    TArray<float> SPCost; // the normal prices, by index in UCMSkillsPage.Skills
    TArray<int> OreCost;
}

class UCMSkillsPage : UCMPage
{
    TArray<TSubclassOf<UGE_Skill_Generic>> Skills;
    TArray<FString> Labels;
    TArray<FName> Chains; // levels of one skill share a chain; a higher level replaces a lower one
    float TrainLP = -1; // learning points while free training is on; this page lives as long as the hero
    float SinceCheck = 0;

    UCMSkillState S() const
    {
        return Cast<UCMSkillState>(UCMSkillState::StaticClass().GetDefaultObject());
    }

    FString GetTitle() const override
    {
        return "Skills";
    }

    FString GetHint() const override
    {
        return "[Enter] Learn   [Left] Remove   [Backspace] Back   [F7] Close";
    }

    void Add(FString Label, TSubclassOf<UGE_Skill_Generic> Skill, FName Chain = NAME_None)
    {
        Labels.Add(Label);
        Skills.Add(Skill);
        Chains.Add(Chain);
    }

    // a higher level of the same skill is learned
    bool HasHigher(int i)
    {
        if (Chains[i] == NAME_None)
            return false;
        for (int j = i + 1; j < Skills.Num(); j++)
        {
            if (Chains[j] == Chains[i] && Has(j))
                return true;
        }
        return false;
    }

    // a basic skill comes before its master level
    void Fill()
    {
        Add("Acrobatics", UGE_Skill_Acrobatics);
        Add("Sneak", UGE_Skill_Sneak);
        Add("Diving", UGE_Skill_Diving);
        Add("Wall climbing", UGE_Skill_Wallclimbing);
        Add("Riding", UGE_Skill_Riding);
        Add("Scavenging", UGE_Skill_Scavenging);
        Add("One-handed: trained", UGE_Skill_Melee_OneHanded_Trained, n"Onehanded");
        Add("One-handed: master", UGE_Skill_Melee_OneHanded_Master, n"Onehanded");
        Add("Two-handed: trained", UGE_Skill_Melee_TwoHanded_Trained, n"Twohanded");
        Add("Two-handed: master", UGE_Skill_Melee_TwoHanded_Master, n"Twohanded");
        Add("Fists: trained", UGE_Skill_Melee_Fists_Trained, n"Fists");
        Add("Fists: master", UGE_Skill_Melee_Fists_Master, n"Fists");
        Add("Orc weapons: trained", UGE_Skill_Melee_Orc_Trained, n"Orcweapons");
        Add("Orc weapons: master", UGE_Skill_Melee_Orc_Master, n"Orcweapons");
        Add("Bow: trained", UGE_Skill_Ranged_Bow_Trained, n"Bow");
        Add("Bow: master", UGE_Skill_Ranged_Bow_Master, n"Bow");
        Add("Crossbow: trained", UGE_Skill_Ranged_Crossbow_Trained, n"Crossbow");
        Add("Crossbow: master", UGE_Skill_Ranged_Crossbow_Master, n"Crossbow");
        Add("Magic: circle 1", UGE_Skill_Mage_Circle_1, n"Magic");
        Add("Magic: circle 2", UGE_Skill_Mage_Circle_2, n"Magic");
        Add("Magic: circle 3", UGE_Skill_Mage_Circle_3, n"Magic");
        Add("Magic: circle 4", UGE_Skill_Mage_Circle_4, n"Magic");
        Add("Magic: circle 5", UGE_Skill_Mage_Circle_5, n"Magic");
        Add("Magic: circle 6", UGE_Skill_Mage_Circle_6, n"Magic");
        Add("Lockpicking: skilled", UGE_Skill_Picklock_Skilled, n"Lockpicking");
        Add("Lockpicking: master", UGE_Skill_Picklock_Master, n"Lockpicking");
        Add("Pickpocketing: skilled", UGE_Skill_Pickpocket_Skilled, n"Pickpocketing");
        Add("Pickpocketing: master", UGE_Skill_Pickpocket_Master, n"Pickpocketing");
        Add("Mining: skilled", UGE_Skill_Mining_Skilled, n"Mining");
        Add("Mining: master", UGE_Skill_Mining_Master, n"Mining");
        Add("Orcish: skilled", UGE_Skill_Orcish_Skilled, n"Orcish");
        Add("Orcish: master", UGE_Skill_Orcish_Master, n"Orcish");
        Add("Alchemy", UGE_Skill_Crafting_Alchemy);
        Add("Scroll inscription", UGE_Skill_Crafting_Inscription);
        Add("Smithing: trained", UGE_Skill_Crafting_Blacksmith_Trained, n"Smithing");
        Add("Smithing: master", UGE_Skill_Crafting_Blacksmith_Master, n"Smithing");
        Add("Hunting: teeth", UGE_Skill_Hunting_Teeth_Trained);
        Add("Hunting: claws", UGE_Skill_Hunting_Claw_Trained);
        Add("Hunting: fur", UGE_Skill_Hunting_Fur_Trained);
        Add("Hunting: skin", UGE_Skill_Hunting_Skin_Trained);
        Add("Hunting: reptile skin", UGE_Skill_Hunting_Reptiles_Trained);
        Add("Hunting: stings", UGE_Skill_Hunting_Stings_Trained);
        Add("Hunting: bloodfly stings", UGE_Skill_Hunting_StingsBloodfly_Trained);
        Add("Hunting: organs", UGE_Skill_Hunting_Organ_Trained);
        Add("Hunting: fins", UGE_Skill_Hunting_Fins_Trained);
        Add("Hunting: secretion", UGE_Skill_Hunting_Secretion_Trained);
        Add("Hunting: spines", UGE_Skill_Hunting_Spines_Trained);
        Add("Hunting: scutes", UGE_Skill_Hunting_Scutes_Trained, n"Scutes");
        Add("Hunting: scutes master", UGE_Skill_Hunting_Scutes_Master, n"Scutes");
        Add("Hunting: minecrawler plates", UGE_Skill_Hunting_MCPlate_Trained);
        Add("Hunting: minecrawler mandibles", UGE_Skill_Hunting_MandibleMineCrawler_Trained);
        Add("Hunting: shadowbeast horn", UGE_Skill_Hunting_ShadowbeastHorn_Trained);
        Add("Hunting: troll horn", UGE_Skill_Hunting_TrollHorn_Trained);
        Add("Hunting: swampshark skin", UGE_Skill_Hunting_SkinSwampshark_Trained);
        Add("Hunting: swampshark teeth", UGE_Skill_Hunting_TeethSwampshark_Trained);
        Add("Hunting: fire tongue", UGE_Skill_Hunting_TongueOfFire_Trained);
        Add("Hunting: skull armour", UGE_Skill_Hunting_SkullArmor_Trained);
        Add("Hunting: Ulu-Mulu", UGE_Skill_Hunting_UluMulu_Trained);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Skills.Num() == 0 || Chains.Num() != Skills.Num())
        {
            Skills.Reset();
            Labels.Reset();
            Chains.Reset();
            Fill();
        }
        Items.Add(CM::Item("Learn all skills", ECMKind::Action, n"All"));
        Items.Add(CM::Item("Free training", ECMKind::Toggle, n"Train"));
        Items.Add(CM::Item("Reset skills", ECMKind::Action, n"Reset"));
        for (int i = 0; i < Skills.Num(); i++)
            Items.Add(CM::Item(Labels[i], ECMKind::Value, FName("Skill" + i)));
    }

    int SkillIndex(FName Id)
    {
        FString s = Id.ToString();
        if (!s.StartsWith("Skill"))
            return -1;
        int i = String::Conv_StringToInt(s.RightChop(5));
        return i < Skills.Num() ? i : -1;
    }

    UGE_Skill_Generic Defaults(int i)
    {
        return Cast<UGE_Skill_Generic>(Skills[i].Get().GetDefaultObject());
    }

    bool Has(int i)
    {
        UGothicAbilitySystemComponent asc = CM::HeroASC();
        return asc != nullptr && asc.GetGameplayEffectCount(Skills[i], nullptr, true) > 0;
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"Train")
            return CM::OnOff(S().bTrain);
        int i = SkillIndex(Id);
        if (i < 0)
            return "";
        return Has(i) ? "learned" : "";
    }

    FString Activate(FName Id, int Dir) override
    {
        AGothicCharacter hero = CM::Hero();
        AGothicCharacterState state = hero != nullptr ? hero.GetCharacterState() : nullptr;
        if (state == nullptr)
            return CM::NotInGame;
        if (Id == n"All")
        {
            int learned = 0;
            for (int i = 0; i < Skills.Num(); i++)
            {
                if (Has(i) || HasHigher(i) || state.LearnSkillForFree(Skills[i]))
                    learned++;
            }
            return CM::F("Learned {0} of {1} skills", "" + learned, "" + Skills.Num());
        }
        if (Id == n"Train")
            return SetTraining(!S().bTrain);
        if (Id == n"Reset")
            return Reset();
        int i = SkillIndex(Id);
        if (i < 0)
            return "";
        if (Dir < 0)
        {
            if (!Has(i))
                return CM::F("{0}: not learned", Labels[i]);
            CM::HeroASC().RemoveActiveGameplayEffectBySourceEffect(Skills[i], nullptr, -1);
            return Has(i) ? "Removing failed" : CM::F("Removed: {0}", Labels[i]);
        }
        if (Has(i))
            return CM::F("{0}: already learned", Labels[i]);
        return state.LearnSkillForFree(Skills[i]) ? CM::F("Learned: {0}", Labels[i]) : "Learning failed";
    }

    // the normal prices, read once while they are untouched
    void ReadPrices()
    {
        UCMSkillState s = S();
        if (s.bPricesRead)
            return;
        s.SPCost.Reset();
        s.OreCost.Reset();
        for (int i = 0; i < Skills.Num(); i++)
        {
            UGE_Skill_Generic cdo = Defaults(i);
            s.SPCost.Add(cdo != nullptr ? cdo.m_SPCost : 0.0);
            s.OreCost.Add(cdo != nullptr ? cdo.OreCost : 0);
        }
        s.bPricesRead = true;
    }

    FString SetTraining(bool bOn)
    {
        ReadPrices();
        UCMSkillState s = S();
        for (int i = 0; i < Skills.Num(); i++)
        {
            UGE_Skill_Generic cdo = Defaults(i);
            if (cdo == nullptr)
                continue;
            cdo.m_SPCost = bOn ? 0.0 : s.SPCost[i];
            cdo.OreCost = bOn ? 0 : s.OreCost[i];
        }
        s.bTrain = bOn;
        TrainLP = -1;
        return CM::F("Free training {0}", CM::OnOff(bOn));
    }

    // Every skill the hero has is removed and its learning points are given back, at the normal
    // price also while free training is on. The ore paid for it is not given back.
    FString Reset()
    {
        ReadPrices();
        UGothicAbilitySystemComponent asc = CM::HeroASC();
        int removed = 0;
        float refund = 0;
        for (int i = 0; i < Skills.Num(); i++)
        {
            if (!Has(i))
                continue;
            asc.RemoveActiveGameplayEffectBySourceEffect(Skills[i], nullptr, -1);
            if (!Has(i))
            {
                removed++;
                refund += S().SPCost[i];
            }
        }
        if (refund > 0)
            CM::SetAttr(UAttributeSet_LevelProgression, n"Skillpoints", CM::BaseAttr(UAttributeSet_LevelProgression, n"Skillpoints", 0) + refund);
        TrainLP = -1;
        return CM::F("Removed {0} skill(s), {1} learning points back", "" + removed, CM::Num(refund));
    }

    // free training: learning points that drop (stat training) are set back
    void Tick(float DeltaSeconds) override
    {
        if (!S().bTrain)
            return;
        SinceCheck += DeltaSeconds;
        if (SinceCheck < 0.25)
            return;
        SinceCheck = 0;
        float lp = CM::Attr(UAttributeSet_LevelProgression, n"Skillpoints");
        if (lp < 0)
            return;
        if (TrainLP >= 0 && lp < TrainLP)
            CM::SetAttr(UAttributeSet_LevelProgression, n"Skillpoints", TrainLP);
        else
            TrainLP = lp;
    }
}
