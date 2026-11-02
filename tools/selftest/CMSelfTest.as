// G1R Cheat Menu self-test bot (test only: run-selftest.ps1 copies it into the deployed mod; it never
// goes into Kandro78-G1RCheatMenu). Starts by itself a few seconds after a save is loaded, checks
// every page, opens each main page for a screenshot and writes its lines to the save slot below,
// which run-selftest.ps1 reads (the shipping game has no log).

class UCMSelfTestResult : USaveGame
{
    UPROPERTY()
    TArray<FString> Lines;
}

class UCMSelfTest : UGothicModExt_WorldSubsystem
{
    const FString Slot = "Kandro78-G1RCheatMenu-SelfTest";
    const float StepSeconds = 0.1;
    const float StartDelay = 5.0;
    const float ShotOpenDelay = 1.0; // the panel needs a frame or two before it is drawn
    const float ShotHoldTime = 2.5;  // run-selftest.ps1 polls the slot and captures within this time

    TArray<FString> Lines;
    int Passed = 0;
    int Failed = 0;
    float Waited = 0;
    int Phase = 0; // 0 wait for the hero, 1 checks, 2 shots, 3 done
    int Shot = -1;

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

    UFUNCTION()
    void OnStep()
    {
        UCMMenu menu = UCMMenu::Get();
        if (menu == nullptr || CM::Hero() == nullptr || Phase == 3)
            return;
        menu.Setup();
        Waited += StepSeconds;
        if (Phase == 0)
        {
            if (Waited < StartDelay)
                return;
            Write("START");
            RunChecks(menu);
            Phase = 2;
            Waited = 0;
            menu.Stack.Reset();
            menu.SetOpen(true); // shot 0: the main page
            menu.Refresh();
        }
        else if (Phase == 2)
            StepShots(menu);
    }

    void RunChecks(UCMMenu Menu)
    {
        Check(Menu.MainPage.Pages.Num() > 0, "main page has pages", "" + Menu.MainPage.Pages.Num());
        TArray<UCMPage> seen;
        for (UCMPage page : Menu.MainPage.Pages)
            CheckPage(page, page.GetTitle(), 0, seen);
        CheckFaction(Menu);
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

    // a real cheat round trip: switch the faction and put the old one back
    void CheckFaction(UCMMenu Menu)
    {
        UCMFactionPage faction;
        for (UCMPage page : Menu.MainPage.Pages)
        {
            if (Cast<UCMFactionPage>(page) != nullptr)
                faction = Cast<UCMFactionPage>(page);
        }
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

    // shot -1 is the main page, then each main page; the menu is opened through its own functions
    void StepShots(UCMMenu Menu)
    {
        if (Waited < ShotOpenDelay + ShotHoldTime)
        {
            if (Waited >= ShotOpenDelay && Waited - StepSeconds < ShotOpenDelay)
                Write("SHOT " + (Shot + 1) + " " + (Shot < 0 ? "Main" : Menu.MainPage.Pages[Shot].GetTitle()));
            return;
        }
        Shot++;
        Waited = 0;
        if (Shot >= Menu.MainPage.Pages.Num())
        {
            Menu.SetOpen(false);
            Menu.Stack.Reset();
            Write("DONE " + Passed + " passed, " + Failed + " failed");
            Phase = 3;
            return;
        }
        Menu.Stack.Reset();
        Menu.SetOpen(true);
        Menu.MainPage.Selected = Shot;
        Menu.OpenPage(Menu.MainPage.Pages[Shot]);
        Menu.Refresh();
    }
}
