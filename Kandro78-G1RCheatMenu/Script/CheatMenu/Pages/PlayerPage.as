// G1R Cheat Menu: Player page.
// The switches live in UCMPlayerState's class default object, which lasts for the whole game
// session: loading a save makes a new world and a new menu, and the switches carry over.

class UCMPlayerState : UObject
{
    bool bGod = false;
    bool bMana = false;
    bool bBreath = false;
    bool bOneHit = false;
    bool bPicks = false;
    bool bNoFall = false;
    bool bAmmo = false;
    bool bPocket = false;
    float HeroSpeed = 1.0;
    float Jump = 1.0;

    // values the switches replaced, put back when they go off and before every save
    float PicksBase = -1.0;
    float PocketBase = -1.0;
    float JumpBase = -1.0;
    bool bFallGod = false; // the combat config's god flag is set for a fall in progress
    float LandedFor = 0.0;
}

class UCMPlayerPage : UCMPage
{
    const float PicksHigh = 1000.0;
    const float PocketHigh = 100.0;
    const float OneHitRange = 4000.0; // 40 m
    const int AmmoLow = 50;
    const int AmmoFull = 99;
    const float GodAfterLanding = 1.0; // seconds

    float SlowTimer = 0.0;
    float OneHitTimer = 0.0;

    UCMPlayerState S() const
    {
        return Cast<UCMPlayerState>(UCMPlayerState::StaticClass().GetDefaultObject());
    }

    FString GetTitle() const override
    {
        return "Player";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        Items.Add(CM::Item("God mode", ECMKind::Toggle, n"God"));
        Items.Add(CM::Item("Infinite mana", ECMKind::Toggle, n"Mana"));
        Items.Add(CM::Item("Infinite breath", ECMKind::Toggle, n"Breath"));
        Items.Add(CM::Item("Fly", ECMKind::Toggle, n"Fly"));
        Items.Add(CM::Item("One-hit kills", ECMKind::Toggle, n"OneHit"));
        Items.Add(CM::Item("Unbreakable lockpicks", ECMKind::Toggle, n"Picks"));
        Items.Add(CM::Item("No fall damage", ECMKind::Toggle, n"NoFall"));
        Items.Add(CM::Item("Infinite ammo", ECMKind::Toggle, n"Ammo"));
        Items.Add(CM::Item("Invisible to NPCs", ECMKind::Toggle, n"Invisible"));
        Items.Add(CM::Item("Sure pickpocketing", ECMKind::Toggle, n"Pocket"));
        Items.Add(CM::Item("Unlock chest or door in view", ECMKind::Action, n"Unlock"));
        Items.Add(CM::Item("Hero speed", ECMKind::Value, n"Speed"));
        Items.Add(CM::Item("Jump height", ECMKind::Value, n"Jump"));
        Items.Add(CM::Item("Restore health and mana", ECMKind::Action, n"Heal"));
        Items.Add(CM::Item("Clear crimes", ECMKind::Action, n"Crimes"));
    }

    FString GetValue(FName Id) override
    {
        UCMPlayerState s = S();
        if (Id == n"God")
            return CM::OnOff(s.bGod);
        if (Id == n"Mana")
            return CM::OnOff(s.bMana);
        if (Id == n"Breath")
            return CM::OnOff(s.bBreath);
        if (Id == n"Fly")
            return CM::OnOff(IsFlying());
        if (Id == n"OneHit")
            return CM::OnOff(s.bOneHit);
        if (Id == n"Picks")
            return CM::OnOff(s.bPicks);
        if (Id == n"NoFall")
            return CM::OnOff(s.bNoFall);
        if (Id == n"Ammo")
            return CM::OnOff(s.bAmmo);
        if (Id == n"Invisible")
            return CM::OnOff(UPerceptionSystem::DebugGetIgnorePlayerPerceptionsRef());
        if (Id == n"Pocket")
            return CM::OnOff(s.bPocket);
        if (Id == n"Speed")
            return CM::Num(s.HeroSpeed) + "x";
        if (Id == n"Jump")
            return CM::Num(s.Jump) + "x";
        return "";
    }

    FString Activate(FName Id, int Dir) override
    {
        AGothicCharacter hero = CM::Hero();
        if (hero == nullptr)
            return CM::NotInGame;
        UCMPlayerState s = S();

        if (Id == n"God")
        {
            SetGod(!s.bGod);
            return CM::F("God mode {0}", CM::OnOff(s.bGod));
        }
        if (Id == n"Mana")
        {
            s.bMana = !s.bMana;
            return CM::F("Infinite mana {0}", CM::OnOff(s.bMana));
        }
        if (Id == n"Breath")
        {
            s.bBreath = !s.bBreath;
            return CM::F("Infinite breath {0}", CM::OnOff(s.bBreath));
        }
        if (Id == n"Fly")
        {
            AGothicPlayerControllerBase pc = Cast<AGothicPlayerControllerBase>(Gameplay::GetPlayerController(0));
            if (pc == nullptr)
                return CM::NotInGame;
            pc.Cheat_ToggleDebugMovement();
            return CM::F("Fly {0}", CM::OnOff(IsFlying()));
        }
        if (Id == n"OneHit")
        {
            s.bOneHit = !s.bOneHit;
            return CM::F("One-hit kills {0}", CM::OnOff(s.bOneHit));
        }
        if (Id == n"Picks")
        {
            SetPicks(!s.bPicks);
            return CM::F("Unbreakable lockpicks {0}", CM::OnOff(s.bPicks));
        }
        if (Id == n"NoFall")
        {
            s.bNoFall = !s.bNoFall;
            if (!s.bNoFall)
                EndFallGod();
            return CM::F("No fall damage {0}", CM::OnOff(s.bNoFall));
        }
        if (Id == n"Ammo")
        {
            s.bAmmo = !s.bAmmo;
            if (s.bAmmo)
                TopUpAmmo(hero);
            return CM::F("Infinite ammo {0}", CM::OnOff(s.bAmmo));
        }
        if (Id == n"Invisible")
        {
            bool on = !UPerceptionSystem::DebugGetIgnorePlayerPerceptionsRef();
            UPerceptionSystem::DebugGetIgnorePlayerPerceptionsRef() = on;
            return CM::F("Invisible to NPCs {0}", CM::OnOff(on));
        }
        if (Id == n"Pocket")
        {
            SetPocket(!s.bPocket);
            return CM::F("Sure pickpocketing {0}", CM::OnOff(s.bPocket));
        }
        if (Id == n"Unlock")
        {
            UCheatModeHelper::OpenLock(hero);
            return "Unlock: done (works on the chest or door the hero faces)";
        }
        if (Id == n"Speed")
        {
            s.HeroSpeed = NextFactor(s.HeroSpeed, Dir);
            ApplyMovement(hero);
            return CM::F("Hero speed: {0}x", CM::Num(s.HeroSpeed));
        }
        if (Id == n"Jump")
        {
            s.Jump = NextFactor(s.Jump, Dir);
            ApplyMovement(hero);
            return CM::F("Jump height: {0}x", CM::Num(s.Jump));
        }
        if (Id == n"Heal")
        {
            CM::Fill(UAttributeSet_Health, n"Health", n"MaxHealth");
            CM::Fill(UAttributeSet_Mana, n"Mana", n"MaxMana");
            return "Health and mana restored";
        }
        if (Id == n"Crimes")
            return ClearCrimes(hero);
        return "";
    }

    // ---- switches --------------------------------------------------------------------------

    // God mode: the game's own developer flag on the combat config (Damage.as checks it for the
    // player, falls included) plus the invulnerable tag Marvin Mode uses; the tick keeps health
    // full for damage that goes another way
    void SetGod(bool bOn)
    {
        S().bGod = bOn;
        UCombatConfig cfg = CM::CombatConfig();
        if (cfg != nullptr && !S().bFallGod)
            cfg.SetGodMode(bOn);
        UGothicAbilitySystemComponent asc = CM::HeroASC();
        if (asc == nullptr)
            return;
        if (bOn && !asc.HasGameplayTag(GameplayTag::State_Invulnerable))
            asc.AddLooseGameplayTag(GameplayTag::State_Invulnerable);
        else if (!bOn && asc.HasGameplayTag(GameplayTag::State_Invulnerable))
            asc.RemoveLooseGameplayTag(GameplayTag::State_Invulnerable);
    }

    bool IsFlying()
    {
        AGothicPlayerControllerBase pc = Cast<AGothicPlayerControllerBase>(Gameplay::GetPlayerController(0));
        return pc != nullptr && pc.IsCheatDebugMovementEnabled();
    }

    // Lockpicks: the hero's lockpick durability is held high
    void SetPicks(bool bOn)
    {
        UCMPlayerState s = S();
        if (bOn && !s.bPicks)
            s.PicksBase = CM::BaseAttr(UAttributeSet_Lockpicking, n"LockpickDurability");
        s.bPicks = bOn;
        if (bOn)
            CM::SetAttr(UAttributeSet_Lockpicking, n"LockpickDurability", PicksHigh);
        else if (s.PicksBase >= 0)
            CM::SetAttr(UAttributeSet_Lockpicking, n"LockpickDurability", s.PicksBase);
    }

    // Pickpocketing: the hero's pickpocketing value (-30 untrained) is held high
    void SetPocket(bool bOn)
    {
        UCMPlayerState s = S();
        if (bOn && !s.bPocket)
            s.PocketBase = CM::BaseAttr(UAttributeSet_Pickpocketing, n"PickPocketing");
        s.bPocket = bOn;
        if (bOn)
            CM::SetAttr(UAttributeSet_Pickpocketing, n"PickPocketing", PocketHigh);
        else if (s.PocketBase > -1000)
            CM::SetAttr(UAttributeSet_Pickpocketing, n"PickPocketing", s.PocketBase);
    }

    // No fall damage: while the hero falls, the combat config's god flag is on; one second after
    // landing it goes back to what the God mode switch says
    void FallTick(AGothicCharacter Hero, float Dt)
    {
        UCMPlayerState s = S();
        bool falling = Hero.CharacterMovement != nullptr && Hero.CharacterMovement.IsFalling() && !IsFlying();
        UCombatConfig cfg = CM::CombatConfig();
        if (cfg == nullptr)
            return;
        if (falling)
        {
            if (!s.bFallGod)
                cfg.SetGodMode(true);
            s.bFallGod = true;
            s.LandedFor = 0;
        }
        else if (s.bFallGod)
        {
            s.LandedFor += Dt;
            if (s.LandedFor >= GodAfterLanding)
                EndFallGod();
        }
    }

    void EndFallGod()
    {
        UCMPlayerState s = S();
        if (!s.bFallGod)
            return;
        s.bFallGod = false;
        UCombatConfig cfg = CM::CombatConfig();
        if (cfg != nullptr)
            cfg.SetGodMode(s.bGod);
    }

    // Hero speed: the hero's own time dilation, so walking, climbing and attacks all run faster
    // (movement comes from the animations). Jump height: the jump velocity times the factor.
    float NextFactor(float Current, int Dir)
    {
        TArray<float> factors;
        factors.Add(1.0);
        factors.Add(1.5);
        factors.Add(2.0);
        factors.Add(3.0);
        int index = 0;
        for (int i = 0; i < factors.Num(); i++)
        {
            if (Math::Abs(factors[i] - Current) < 0.01)
                index = i;
        }
        return factors[Math::Clamp(index + Dir, 0, factors.Num() - 1)];
    }

    void ApplyMovement(AGothicCharacter Hero)
    {
        UCMPlayerState s = S();
        if (Math::Abs(Hero.CustomTimeDilation - s.HeroSpeed) > 0.01)
            Hero.SetCustomTimeDilation(float32(s.HeroSpeed));
        UCharacterMovementComponent move = Hero.CharacterMovement;
        if (move == nullptr)
            return;
        if (s.JumpBase < 0)
            s.JumpBase = move.JumpZVelocity;
        float want = s.JumpBase * s.Jump;
        if (Math::Abs(move.JumpZVelocity - want) > 1)
            move.JumpZVelocity = want;
    }

    // Infinite ammo: arrows and bolts are topped up when they drop below AmmoLow
    void TopUpAmmo(AGothicCharacter Hero)
    {
        UInventoryComponent inv = Hero.GetInventory();
        if (inv == nullptr)
            return;
        TopUp(inv, UItAm_Arrow::StaticClass());
        TopUp(inv, UItAm_Bolt::StaticClass());
    }

    void TopUp(UInventoryComponent Inv, TSubclassOf<UItemDefinition> Ammo)
    {
        int count = Inv.CountItemsOfClass(Ammo);
        if (count < AmmoLow)
            Inv.AddItemOfClass(Ammo, AmmoFull - count);
    }

    // One-hit kills: a hostile character near the hero that has lost health (it was hit) dies
    void OneHitTick(AGothicCharacter Hero)
    {
        AGothicCharacterState heroState = Hero.GetCharacterState();
        if (heroState == nullptr)
            return;
        TArray<AActor> actors;
        GetAllActorsOfClass(AGothicCharacter::StaticClass(), actors);
        for (AActor actor : actors)
        {
            AGothicCharacter npc = Cast<AGothicCharacter>(actor);
            if (npc == nullptr || npc == Hero || npc.IsDead() || npc.GetDistanceTo(Hero) > OneHitRange)
                continue;
            AGothicCharacterState npcState = npc.GetCharacterState();
            if (npcState == nullptr || !(npcState.IsHostileTowards(heroState) || npcState.IsAngryTowards(heroState)))
                continue;
            float health = npc.GetHealthAttribute();
            if (health <= 0 || health >= npc.GetMaxHealthAttribute())
                continue;
            UAbilitySystemComponent asc = npc.GetAbilitySystemComponent();
            if (asc != nullptr)
                asc.ApplyGameplayEffectToSelf(UGameplayEffect_DebugKillCharacter::StaticClass(), 0, asc.MakeEffectContext());
        }
    }

    FString ClearCrimes(AGothicCharacter Hero)
    {
        UCrimeMemorySubsystem crimes = UCrimeMemorySubsystem::Get(Hero);
        AGothicCharacterState heroState = Hero.GetCharacterState();
        if (crimes == nullptr || heroState == nullptr)
            return "Crime memory not found";
        TArray<int> ids = crimes.GetAllCrimesCommitedBy(heroState);
        TArray<int> done;
        for (int id : ids)
        {
            if (done.Contains(id))
                continue;
            done.Add(id);
            crimes.ForgiveCrime(id);
            crimes.RemoveCrime(id);
        }
        if (done.Num() == 0)
            return "No crimes on record";
        return "Crimes cleared";
    }

    // ---- tick ------------------------------------------------------------------------------

    void Tick(float DeltaSeconds) override
    {
        AGothicCharacter hero = CM::Hero();
        if (hero == nullptr)
            return;
        UCMPlayerState s = S();

        if (s.bGod)
            CM::Fill(UAttributeSet_Health, n"Health", n"MaxHealth");
        if (s.bMana)
            CM::Fill(UAttributeSet_Mana, n"Mana", n"MaxMana");
        if (s.bBreath)
            CM::Fill(UAttributeSet_Oxygen, n"Oxygen", n"MaxOxygen");
        if (s.bNoFall || s.bFallGod)
            FallTick(hero, DeltaSeconds);

        OneHitTimer += DeltaSeconds;
        if (s.bOneHit && OneHitTimer >= 0.5)
        {
            OneHitTimer = 0;
            OneHitTick(hero);
        }

        // once a second: values the game may set back, and a hero made new by loading a save
        SlowTimer += DeltaSeconds;
        if (SlowTimer < 1.0)
            return;
        SlowTimer = 0;
        if (s.bGod)
            SetGod(true);
        if (s.bPicks && CM::Attr(UAttributeSet_Lockpicking, n"LockpickDurability") < PicksHigh)
            CM::SetAttr(UAttributeSet_Lockpicking, n"LockpickDurability", PicksHigh);
        if (s.bPocket && CM::Attr(UAttributeSet_Pickpocketing, n"PickPocketing") < PocketHigh)
            CM::SetAttr(UAttributeSet_Pickpocketing, n"PickPocketing", PocketHigh);
        if (s.bAmmo)
            TopUpAmmo(hero);
        ApplyMovement(hero);
    }

    void BeforeSave() override
    {
        UCMPlayerState s = S();
        if (s.bPicks && s.PicksBase >= 0)
            CM::SetAttr(UAttributeSet_Lockpicking, n"LockpickDurability", s.PicksBase);
        if (s.bPocket && s.PocketBase > -1000)
            CM::SetAttr(UAttributeSet_Pickpocketing, n"PickPocketing", s.PocketBase);
    }
}
