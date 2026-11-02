// G1R Cheat Menu self-test bot (test only: run-selftest.ps1 copies it into the deployed mod; it never
// goes into Kandro78-G1RCheatMenu). Starts by itself a few seconds after a save is loaded, checks
// every page and a set of cheats that it undoes again, opens each main page for a screenshot and
// writes its lines to the save slot below, which run-selftest.ps1 reads (the shipping game has no log).

class UCMSelfTestResult : USaveGame
{
    UPROPERTY()
    TArray<FString> Lines;
}

class UCMSelfTest : UGothicModExt_WorldSubsystem
{
    // run-selftest.ps1 sets these three in the deployed copy
    const FString Mode = "test";  // "test", or "makesave": only report READY so the bot can quicksave
    const FString Language = "";  // e.g. "en": the game language for the run (not saved to the config)
    const bool bSoak = false;     // after the shots, open and close the menu for 3 minutes

    const FString Slot = "Kandro78-G1RCheatMenu-SelfTest";
    const float StepSeconds = 0.1;
    const float StartDelay = 5.0;
    const float ShotOpenDelay = 1.0; // the panel needs a frame or two before it is drawn
    const float ShotHoldTime = 2.5;  // run-selftest.ps1 polls the slot and captures within this time
    const float TeleportWait = 6.0;  // the ground loads and the teleport hold lets go
    const int SoakCycles = 12;       // 12 x (open 7.5 s + closed 7.5 s) = 3 minutes

    TArray<FString> Lines;
    int Passed = 0;
    int Failed = 0;
    float Waited = 0;
    // 0 wait for the hero, 1 teleport away, 2 teleport back, 3 shots, 4 soak, 5 done
    int Phase = 0;
    int Shot = -1;
    int Soak = 0;
    FVector Start;
    float StartYaw = 0;
    FString OldLanguage;

    UFUNCTION(BlueprintOverride)
    void HandleReadyForPlay()
    {
        System::SetTimer(this, n"OnStep", StepSeconds, true);
    }

    void Write(FString Line)
    {
        Lines.Add("CMT|" + Line);
        UCMSelfTestResult result = Cast<UCMSelfTestResult>(Gameplay::CreateSaveGameObject(UCMSelfTestResult::StaticClass()));
        if (result == nullptr)
            return;
        result.Lines = Lines;
        Gameplay::SaveGameToSlot(result, Slot, 0);
    }

    void Check(bool bOk, FString What, FString Detail = "")
    {
        if (bOk)
            Passed++;
        else
            Failed++;
        Write((bOk ? "PASS " : "FAIL ") + What + (Detail != "" ? " (" + Detail + ")" : ""));
    }

    FString Pos(FVector V)
    {
        return "" + Math::RoundToInt(V.X) + " " + Math::RoundToInt(V.Y) + " " + Math::RoundToInt(V.Z);
    }

    UFUNCTION()
    void OnStep()
    {
        UCMMenu menu = UCMMenu::Get();
        AGothicCharacter hero = CM::Hero();
        if (menu == nullptr || hero == nullptr || Phase == 5)
            return;
        menu.Setup();
        Waited += StepSeconds;
        if (Phase == 0)
        {
            if (Waited < StartDelay)
                return;
            Start = hero.GetActorLocation();
            StartYaw = hero.GetActorRotation().Yaw;
            if (Mode == "makesave")
            {
                Write("READY " + Pos(Start));
                Phase = 5;
                return;
            }
            Write("START " + Pos(Start));
            if (Language != "")
            {
                OldLanguage = Internationalization::GetCurrentLanguage();
                Internationalization::SetCurrentLanguage(Language, false);
                Write("INFO language " + OldLanguage + " > " + Internationalization::GetCurrentLanguage());
            }
            RunChecks(menu);
            UCMTeleportPage teleport = Cast<UCMTeleportPage>(Page(menu, "Teleport"));
            TArray<FCMItem> items;
            teleport.Build(items);
            // the exchange place at the game start, or Xardas' tower when the save is near it
            teleport.Activate(Start.Distance(teleport.Places[0].Location) > 5000 ? n"Place0" : n"Place12", 0);
            Next(1);
        }
        else if (Phase == 1 && Waited >= TeleportWait)
        {
            float moved = hero.GetActorLocation().Distance(Start);
            Check(moved > 1000, "teleport away", "" + Math::RoundToInt(moved) + " units");
            CMTeleport::To(Start, StartYaw, "self-test start", true);
            Next(2);
        }
        else if (Phase == 2 && Waited >= TeleportWait)
        {
            float off = hero.GetActorLocation().Distance(Start);
            Check(off < 300, "teleport back", "" + Math::RoundToInt(off) + " units off");
            menu.Stack.Reset();
            menu.SetOpen(true); // shot 0: the main page
            menu.Refresh();
            Next(3);
        }
        else if (Phase == 3)
            StepShots(menu);
        else if (Phase == 4)
            StepSoak(menu);
    }

    void Next(int NewPhase)
    {
        Phase = NewPhase;
        Waited = 0;
    }

    void Finish(UCMMenu Menu)
    {
        Menu.SetOpen(false);
        Menu.Stack.Reset();
        if (OldLanguage != "")
            Internationalization::SetCurrentLanguage(OldLanguage, false);
        Write("DONE " + Passed + " passed, " + Failed + " failed");
        Phase = 5;
    }

    UCMPage Page(UCMMenu Menu, FString Title)
    {
        for (UCMPage page : Menu.MainPage.Pages)
        {
            if (page.GetTitle() == Title)
                return page;
        }
        return nullptr;
    }

    void RunChecks(UCMMenu Menu)
    {
        Check(Menu.MainPage.Pages.Num() > 0, "main page has pages", "" + Menu.MainPage.Pages.Num());
        TArray<UCMPage> seen;
        for (UCMPage page : Menu.MainPage.Pages)
            CheckPage(page, page.GetTitle(), 0, seen);
        CheckFaction(Menu);

        UCMPage player = Page(Menu, "Player");
        TArray<FName> toggles;
        toggles.Add(n"God");
        toggles.Add(n"Mana");
        toggles.Add(n"Breath");
        toggles.Add(n"OneHit");
        toggles.Add(n"Picks");
        toggles.Add(n"NoFall");
        toggles.Add(n"Ammo");
        toggles.Add(n"Invisible");
        toggles.Add(n"Pocket");
        toggles.Add(n"InstantPick");
        for (FName id : toggles)
            CheckToggle(player, id, "Player " + id.ToString());
        CheckValue(player, n"Speed", "Player hero speed");
        CheckValue(player, n"Jump", "Player jump height");

        UCMPage stats = Page(Menu, "Stats");
        CheckValue(stats, n"Stat0", "Stats strength");
        CheckValue(stats, n"Stat1", "Stats dexterity");

        UCMPage world = Page(Menu, "World");
        CheckToggle(world, n"Freeze", "World freeze time");
        CheckValue(world, n"Speed", "World game speed");
        CheckValue(world, n"DaySpeed", "World day speed");

        CheckOre(Menu);
    }

    // every page builds a non-empty list and every entry answers GetValue; sub-pages too (3 deep)
    void CheckPage(UCMPage Page, FString Path, int Depth, TArray<UCMPage>& Seen)
    {
        if (Page == nullptr || Seen.Contains(Page) || Depth > 3)
            return;
        Seen.Add(Page);
        TArray<FCMItem> items;
        Page.Build(items);
        Check(items.Num() > 0, "build " + Path, "" + items.Num() + " entries");
        for (FCMItem item : items)
        {
            if (item.Kind == ECMKind::Page)
                CheckPage(item.SubPage, Path + " / " + item.Label, Depth + 1, Seen);
            else
                Page.GetValue(item.Id);
        }
    }

    // Enter twice: the value changes and comes back
    void CheckToggle(UCMPage Page, FName Id, FString What)
    {
        if (Page == nullptr)
        {
            Check(false, What, "page missing");
            return;
        }
        FString before = Page.GetValue(Id);
        Page.Activate(Id, 0);
        FString after = Page.GetValue(Id);
        Page.Activate(Id, 0);
        FString back = Page.GetValue(Id);
        Check(after != before && back == before, What, before + " > " + after + " > " + back);
    }

    // Right then Left: the value changes and comes back
    void CheckValue(UCMPage Page, FName Id, FString What)
    {
        if (Page == nullptr)
        {
            Check(false, What, "page missing");
            return;
        }
        TArray<FCMItem> items;
        Page.Build(items);
        FString before = Page.GetValue(Id);
        Page.Activate(Id, 1);
        FString up = Page.GetValue(Id);
        Page.Activate(Id, -1);
        FString back = Page.GetValue(Id);
        Check(up != before && back == before, What, before + " > " + up + " > " + back);
    }

    // Items > "Ore x100" adds 100 ore; the test takes them away again
    void CheckOre(UCMMenu Menu)
    {
        UCMPage items = Page(Menu, "Items");
        UInventoryComponent inventory = CM::Hero().GetInventory();
        if (items == nullptr || inventory == nullptr)
        {
            Check(false, "Items ore x100", "no items page or inventory");
            return;
        }
        TArray<FCMItem> entries;
        items.Build(entries);
        int before = inventory.CountItemsOfClass(UItMi_Orenugget::StaticClass());
        items.Activate(n"Quick0", 0);
        int after = inventory.CountItemsOfClass(UItMi_Orenugget::StaticClass());
        inventory.RemoveItemOfClass(UItMi_Orenugget::StaticClass(), after - before);
        int back = inventory.CountItemsOfClass(UItMi_Orenugget::StaticClass());
        Check(after == before + 100 && back == before, "Items ore x100", "" + before + " > " + after + " > " + back);
    }

    // a real cheat round trip: switch the faction and put the old one back
    void CheckFaction(UCMMenu Menu)
    {
        UCMPage faction = Page(Menu, "Faction");
        if (faction == nullptr)
        {
            Check(false, "faction page found");
            return;
        }
        TArray<FCMItem> items;
        faction.Build(items);
        int old = -1;
        for (int i = 0; i < items.Num(); i++)
        {
            if (faction.GetValue(items[i].Id) == "current")
                old = i;
        }
        if (old < 0)
        {
            Write("SKIP faction round trip (no current faction)");
            return;
        }
        int other = old == 2 ? 1 : 2; // Old Camp: Shadow, or Digger if he is a Shadow already
        faction.Activate(items[other].Id, 0);
        Check(faction.GetValue(items[other].Id) == "current", "faction set", items[other].Label);
        faction.Activate(items[old].Id, 0);
        Check(faction.GetValue(items[old].Id) == "current", "faction restored", items[old].Label);
    }

    // the panel's rectangle in screen pixels, for cropping: the widget draws from Left / Top with the
    // width Layout worked out; the height is the title block, the visible rows and the footer
    FString PanelRect(UCMMenu Menu)
    {
        UCMWidget panel = Menu.Panel;
        if (panel == nullptr)
            return "";
        float scale = WidgetLayout::GetViewportScale();
        int rows = Math::Min(panel.Labels.Num(), panel.VisibleRows);
        float height = panel.ListTop + rows * panel.RowH + 90;
        return "|" + Math::RoundToInt(panel.Left * scale) + "|" + Math::RoundToInt(panel.Top * scale)
            + "|" + Math::RoundToInt((panel.Left + panel.Width) * scale) + "|" + Math::RoundToInt((panel.Top + height) * scale);
    }

    // shot 0 is the main page, then each main page; the menu is opened through its own functions
    void StepShots(UCMMenu Menu)
    {
        if (Waited < ShotOpenDelay + ShotHoldTime)
        {
            if (Waited >= ShotOpenDelay && Waited - StepSeconds < ShotOpenDelay)
                Write("SHOT " + (Shot + 1) + " " + (Shot < 0 ? "Main" : Menu.MainPage.Pages[Shot].GetTitle()) + PanelRect(Menu));
            return;
        }
        Shot++;
        Waited = 0;
        if (Shot >= Menu.MainPage.Pages.Num())
        {
            Menu.SetOpen(false);
            Menu.Stack.Reset();
            if (bSoak)
                Next(4);
            else
                Finish(Menu);
            return;
        }
        Menu.Stack.Reset();
        Menu.SetOpen(true);
        Menu.MainPage.Selected = Shot;
        Menu.OpenPage(Menu.MainPage.Pages[Shot]);
        Menu.Refresh();
    }

    // the 2.2.0 crash came 30-60 s into opening and closing the menu; a crash ends the game, which
    // run-selftest.ps1 reports as a failure
    void StepSoak(UCMMenu Menu)
    {
        if (Waited < 7.5)
            return;
        Waited = 0;
        if (!Menu.bOpen)
        {
            Soak++;
            if (Soak > SoakCycles)
            {
                Check(true, "soak", "" + SoakCycles + " open / close cycles");
                Finish(Menu);
                return;
            }
            Write("SOAK " + Soak + " / " + SoakCycles);
        }
        Menu.SetOpen(!Menu.bOpen);
    }
}
