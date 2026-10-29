// G1R Cheat Menu: NPCs page. The NPC in view (heal, kill, revive), spawning creatures, the attitude
// of each camp, and actions on every loaded NPC (only those within about 45 m of the hero are loaded).

// camp attitudes, kept for the whole game session like UCMPlayerState
class UCMNpcState : UObject
{
    TArray<int> Attitudes; // per camp: 0 Normal, 1 Friendly
}

class UCMSpawnPage : UCMPage
{
    TArray<FString> Labels;
    TArray<FString> Defs; // SpawnAIAgentDefinition_<name>, the game's own spawn definitions

    FString GetTitle() const override
    {
        return "Spawn creature";
    }

    FString GetHint() const override
    {
        return "[Enter] Spawn   [Backspace] Back   [F7] Close";
    }

    void Add(FString Label, FString Def)
    {
        Labels.Add(Label);
        Defs.Add(Def);
    }

    void Fill()
    {
        Add("Meatbug", "Meatbug");
        Add("Bloodfly", "Bloodfly");
        Add("Molerat", "Molerat");
        Add("Scavenger", "ScavengerAdult");
        Add("Wolf", "Wolf");
        Add("Orc Dog", "OrcDog");
        Add("Snapper", "Snapper");
        Add("Razor", "Razor");
        Add("Biter", "Biter");
        Add("Bloodhound", "Bloodhound");
        Add("Lurker", "Lurker");
        Add("Lizard", "Lizard");
        Add("Fire Lizard", "LizardFire");
        Add("Swampshark", "Swampshark");
        Add("Minecrawler", "Minecrawler");
        Add("Minecrawler Warrior", "Minecrawler_Warrior");
        Add("Harpy", "Harpy");
        Add("Shadowbeast", "ShadowBeast");
        Add("Goblin", "Goblin_Green_Sword");
        Add("Black Goblin", "Goblin_Black");
        Add("Young Troll", "TrollYoung");
        Add("Troll", "Troll");
        Add("Skeleton", "Skeleton");
        Add("Skeleton Warrior", "SkeletonWarrior");
        Add("Skeleton Mage", "SkeletonMage");
        Add("Zombie", "Zombie");
        Add("Stone Golem", "GolemStone");
        Add("Fire Golem", "GolemFire");
        Add("Ice Golem", "GolemIce");
        Add("Demon", "DemonLesser");
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Labels.Num() == 0)
            Fill();
        for (int i = 0; i < Labels.Num(); i++)
            Items.Add(CM::Item(Labels[i], ECMKind::Action, FName("Spawn" + i)));
    }

    // 6 m in front of the hero, the way Marvin Mode spawns
    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(5));
        if (!s.StartsWith("Spawn") || i < 0 || i >= Labels.Num())
            return "";
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        UClass def = UClass::FindClassFromName(FName("SpawnAIAgentDefinition_" + Defs[i]));
        if (def == nullptr || !def.IsChildOf(USpawnAIAgentDefinition::StaticClass()))
            return CM::F("Creature not found: {0}", Labels[i]);
        FVector at = UCheatModeHelper::GetPlayerFrontLocationAtDistance(600);
        UCheatModeHelper::SpawnNPC("Kandro78-G1RCheatMenu", def, UDailyRoutine_Empty::StaticClass(), FTransform(at));
        return CM::F("Spawned: {0}", Labels[i]);
    }
}

// The loaded people of a camp are made friendly towards the hero (and he towards them); people who
// load later follow within a second. What they thought of him before is remembered and put back
// when the camp is set to normal again. There is no "hostile": a camp that starts fighting the hero
// stays hostile whatever the relationship is set back to, which could ruin a playthrough.
class UCMCampsPage : UCMPage
{
    TArray<FString> Labels;
    TArray<FString> Prefixes; // the camp codes in the characters' names, separated by spaces
    TMap<FString, ERelationship> TheirsBefore; // by actor name: how they saw the hero
    TMap<FString, ERelationship> HisBefore;    // and how he saw them
    float SinceTick = 0;

    FString GetTitle() const override
    {
        return "Camp attitude";
    }

    FString GetHint() const override
    {
        return "[Left/Right] Change   [Backspace] Back   [F7] Close";
    }

    UCMNpcState S() const
    {
        return Cast<UCMNpcState>(UCMNpcState::StaticClass().GetDefaultObject());
    }

    void Fill()
    {
        Labels.Add("Old Camp");
        Prefixes.Add("OC OM");
        Labels.Add("New Camp");
        Prefixes.Add("NC");
        Labels.Add("Swamp Camp");
        Prefixes.Add("SC");
        while (S().Attitudes.Num() < Labels.Num())
            S().Attitudes.Add(0);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Labels.Num() == 0)
            Fill();
        for (int i = 0; i < Labels.Num(); i++)
            Items.Add(CM::Item(Labels[i], ECMKind::Value, FName("Camp" + i)));
    }

    FString GetValue(FName Id) override
    {
        int i = String::Conv_StringToInt(Id.ToString().RightChop(4));
        if (i < 0 || i >= S().Attitudes.Num())
            return "";
        return S().Attitudes[i] == 1 ? "Friendly" : "Normal";
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(4));
        if (!s.StartsWith("Camp") || i < 0 || i >= Labels.Num())
            return "";
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        S().Attitudes[i] = 1 - S().Attitudes[i];
        Apply();
        return CM::F("Attitude of {0}: {1}", Labels[i], GetValue(Id));
    }

    // the camp of a character, -1 for none
    int CampOf(AGothicCharacter Npc)
    {
        TArray<FString> tokens = CMNpc::Tokens(Npc.GetName().ToString());
        if (tokens.Num() == 0)
            return -1;
        for (int i = 0; i < Prefixes.Num(); i++)
        {
            TArray<FString> codes;
            Prefixes[i].ParseIntoArray(codes, " ", true);
            if (codes.Contains(tokens[0]))
                return i;
        }
        return -1;
    }

    void Apply()
    {
        AGothicCharacter hero = CM::Hero();
        AGothicCharacterState heroState = hero != nullptr ? hero.GetCharacterState() : nullptr;
        if (heroState == nullptr || Labels.Num() == 0)
            return;
        for (AGothicCharacter npc : CMNpc::Loaded())
        {
            int camp = CampOf(npc);
            AGothicCharacterState st = npc.GetCharacterState();
            if (camp < 0 || st == nullptr)
                continue;
            FString key = npc.GetName().ToString();
            if (S().Attitudes[camp] == 1)
            {
                if (st.GetRelationshipTowards(heroState) == ERelationship::Friend)
                    continue;
                if (!TheirsBefore.Contains(key))
                {
                    TheirsBefore.Add(key, st.GetRelationshipTowards(heroState));
                    HisBefore.Add(key, heroState.GetRelationshipTowards(st));
                }
                st.SetRelationshipTowards(heroState, ERelationship::Friend);
                heroState.SetRelationshipTowards(st, ERelationship::Friend);
            }
            else if (TheirsBefore.Contains(key))
            {
                st.SetRelationshipTowards(heroState, TheirsBefore[key]);
                heroState.SetRelationshipTowards(st, HisBefore[key]);
                // someone who fought the hero keeps a grudge "until defeated" on top
                if (st.GetRelationshipTowards(heroState) != TheirsBefore[key])
                {
                    st.SetRelationshipUntilDefeat(heroState, TheirsBefore[key]);
                    heroState.SetRelationshipUntilDefeat(st, HisBefore[key]);
                }
                TheirsBefore.Remove(key);
                HisBefore.Remove(key);
            }
        }
    }

    void Tick(float DeltaSeconds) override
    {
        SinceTick += DeltaSeconds;
        if (SinceTick < 1)
            return;
        SinceTick = 0;
        if (Labels.Num() == 0)
            Fill();
        bool busy = TheirsBefore.Num() > 0;
        for (int a : S().Attitudes)
        {
            if (a != 0)
                busy = true;
        }
        if (busy)
            Apply();
    }
}

class UCMNpcsPage : UCMPage
{
    UCMSpawnPage Spawn;
    UCMCampsPage Camps;
    const float TargetRange = 2500; // 25 m from the camera
    const float TargetAngle = 12;   // degrees off the middle of the view

    FString GetTitle() const override
    {
        return "NPCs";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Spawn == nullptr)
        {
            Spawn = Cast<UCMSpawnPage>(NewObject(this, UCMSpawnPage::StaticClass()));
            Camps = Cast<UCMCampsPage>(NewObject(this, UCMCampsPage::StaticClass()));
        }
        Items.Add(CM::Item("Heal NPC in view", ECMKind::Action, n"Heal"));
        Items.Add(CM::Item("Kill NPC in view", ECMKind::Action, n"Kill"));
        Items.Add(CM::Item("Revive NPC in view", ECMKind::Action, n"Revive"));
        Items.Add(CM::PageItem("Spawn creature", Spawn));
        Items.Add(CM::PageItem("Camp attitude", Camps));
        Items.Add(CM::Item("Kill hostile NPCs (loaded area)", ECMKind::Action, n"KillHostile"));
        Items.Add(CM::Item("Make loaded NPCs friendly", ECMKind::Action, n"Befriend"));
    }

    // of the loaded characters (living or dead ones), the one nearest the middle of the view;
    // close ones may be off the middle by up to a metre
    AGothicCharacter InView(bool bDead)
    {
        APlayerCameraManager cam = Gameplay::GetPlayerCameraManager(0);
        if (cam == nullptr)
            return nullptr;
        FVector eye = cam.GetCameraLocation();
        FVector forward = cam.GetCameraRotation().ForwardVector;
        AGothicCharacter best = nullptr;
        float bestAngle = 180;
        for (AGothicCharacter npc : CMNpc::Loaded())
        {
            if (npc.IsDead() != bDead)
                continue;
            FVector to = npc.GetActorLocation() - eye;
            float d = to.Size();
            if (d < 1 || d > TargetRange)
                continue;
            float cos = Math::Clamp(to.DotProduct(forward) / d, -1.0, 1.0);
            float angle = Math::RadiansToDegrees(Math::Acos(cos));
            float allowed = Math::Max(TargetAngle, Math::RadiansToDegrees(Math::Atan(100 / d)));
            if (angle < allowed && angle < bestAngle)
            {
                best = npc;
                bestAngle = angle;
            }
        }
        return best;
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"Heal" || Id == n"Kill" || Id == n"Revive")
        {
            AGothicCharacter npc = InView(Id == n"Revive");
            return npc != nullptr ? CMNpc::DisplayName(npc) : "-";
        }
        return "";
    }

    UGothicAbilitySystemComponent ASC(AGothicCharacter Npc)
    {
        return Cast<UGothicAbilitySystemComponent>(Npc.AbilitySystemComponent);
    }

    void FillHealth(AGothicCharacter Npc)
    {
        UGothicAbilitySystemComponent asc = ASC(Npc);
        if (asc == nullptr)
            return;
        float max = asc.GetAttributeCurrentValue(UAttributeSet_Health, n"MaxHealth", -1);
        if (max > 0)
            asc.TrySetAttributeBaseValue(UAttributeSet_Health, n"Health", max);
    }

    FString Activate(FName Id, int Dir) override
    {
        AGothicCharacter hero = CM::Hero();
        AGothicCharacterState heroState = hero != nullptr ? hero.GetCharacterState() : nullptr;
        if (heroState == nullptr)
            return CM::NotInGame;
        if (Id == n"Heal" || Id == n"Kill")
        {
            AGothicCharacter npc = InView(false);
            if (npc == nullptr)
                return "No NPC in view";
            if (Id == n"Heal")
            {
                FillHealth(npc);
                return CM::F("Healed: {0}", CMNpc::DisplayName(npc));
            }
            UGothicAbilitySystemComponent asc = ASC(npc);
            if (asc == nullptr)
                return "Killing failed";
            asc.ApplyGameplayEffectToSelf(UGameplayEffect_DebugKillCharacter::StaticClass(), 0, asc.MakeEffectContext());
            return CM::F("Killed: {0}", CMNpc::DisplayName(npc));
        }
        if (Id == n"Revive")
        {
            // his health is filled and the world simulation is told he lives; the body stays down
            // until the area loads anew (travel away and back)
            AGothicCharacter npc = InView(true);
            if (npc == nullptr)
                return "No dead NPC in view";
            FillHealth(npc);
            AGothicNPCState st = Cast<AGothicNPCState>(npc.GetCharacterState());
            if (st == nullptr)
                return "Reviving failed";
            st.ReviveInSimulation();
            return CM::F("Revived: {0}, stands up once the area reloads", CMNpc::DisplayName(npc));
        }
        if (Id == n"KillHostile")
        {
            int n = 0;
            for (AGothicCharacter npc : CMNpc::Loaded())
            {
                AGothicCharacterState st = npc.GetCharacterState();
                if (st == nullptr || npc.IsDead())
                    continue;
                if (!st.IsEnemyTowards(heroState) && !st.IsHostileTowards(heroState))
                    continue;
                st.Kill(true);
                n++;
            }
            return CM::F("Killed {0} hostile NPC(s)", "" + n);
        }
        if (Id == n"Befriend")
        {
            int n = 0;
            for (AGothicCharacter npc : CMNpc::Loaded())
            {
                AGothicCharacterState st = npc.GetCharacterState();
                if (st == nullptr)
                    continue;
                st.SetRelationshipTowards(heroState, ERelationship::Friend);
                heroState.SetRelationshipTowards(st, ERelationship::Friend);
                n++;
            }
            return CM::F("{0} loaded NPC(s) are now friendly", "" + n);
        }
        return "";
    }

    void Tick(float DeltaSeconds) override
    {
        if (Camps != nullptr)
            Camps.Tick(DeltaSeconds);
    }
}
