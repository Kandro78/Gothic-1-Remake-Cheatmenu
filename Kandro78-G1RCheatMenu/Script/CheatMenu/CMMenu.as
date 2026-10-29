// G1R Cheat Menu: the menu itself. F7 opens and closes it. Up / Down select (held keys repeat and
// stop at the ends), Page Up / Page Down move a screenful, Home / End go to the first / last entry.
// Enter runs or opens, Right opens a page too, Left / Right change values and switch toggles, Left
// on anything else goes back like Backspace. It is an overlay: the game keeps running and keeps
// its own controls.

class UCMMainPage : UCMPage
{
    UPROPERTY()
    TArray<UCMPage> Pages;

    FString GetTitle() const override
    {
        return "Cheat Menu";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        for (UCMPage page : Pages)
            Items.Add(CM::PageItem(page.GetTitle(), page));
    }
}

class UCMMenu : UGothicModExt_WorldSubsystem
{
    UPROPERTY()
    UCMWidget Panel;
    UPROPERTY()
    UCMMainPage MainPage;
    UPROPERTY()
    TArray<UCMPage> Stack; // the open pages, MainPage first

    TArray<FCMItem> Items;
    bool bOpen = false;
    FString Status;
    const float TickSeconds = 0.1;

    // pages and the tick timer, made once per world (loading a save makes a new world and with it
    // a new menu)
    void Setup()
    {
        if (MainPage != nullptr)
            return;
        MainPage = Cast<UCMMainPage>(NewObject(this, UCMMainPage::StaticClass()));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMPlayerPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMStatsPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMFactionPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMSkillsPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMItemsPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMTeleportPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMWorldPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMNpcsPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMQuestsPage::StaticClass())));
        MainPage.Pages.Add(Cast<UCMPage>(NewObject(this, UCMAchievementsPage::StaticClass())));
        System::SetTimer(this, n"OnTick", TickSeconds, true);
    }

    UFUNCTION(BlueprintOverride)
    void HandleReadyForPlay()
    {
        Setup();
    }

    UFUNCTION(BlueprintOverride)
    void HandleBeforeGameSaved()
    {
        if (MainPage == nullptr)
            return;
        for (UCMPage page : MainPage.Pages)
            page.BeforeSave();
    }

    UFUNCTION(BlueprintOverride)
    void HandlePlayerCharacterBeginPlay(AGothicCharacter Character)
    {
        Setup();
        UInputComponent input = UInputComponent::Get(Character);
        if (input == nullptr)
            return;
        FInputActionHandlerDynamicSignature onKey = FInputActionHandlerDynamicSignature(this, n"OnKey");
        FInputActionHandlerDynamicSignature onRepeat = FInputActionHandlerDynamicSignature(this, n"OnKeyRepeat");
        input.BindKey(EKeys::F7, EInputEvent::IE_Pressed, onKey, false);
        for (FKey key : NavigationKeys())
        {
            input.BindKey(key, EInputEvent::IE_Pressed, onKey, false);
            input.BindKey(key, EInputEvent::IE_Repeat, onRepeat, false);
        }
    }

    TArray<FKey> NavigationKeys()
    {
        TArray<FKey> keys;
        keys.Add(EKeys::Up);
        keys.Add(EKeys::Down);
        keys.Add(EKeys::Left);
        keys.Add(EKeys::Right);
        keys.Add(EKeys::Enter);
        keys.Add(EKeys::BackSpace);
        keys.Add(EKeys::PageUp);
        keys.Add(EKeys::PageDown);
        keys.Add(EKeys::Home);
        keys.Add(EKeys::End);
        keys.Add(EKeys::NumPadEight);
        keys.Add(EKeys::NumPadTwo);
        keys.Add(EKeys::NumPadFour);
        keys.Add(EKeys::NumPadSix);
        keys.Add(EKeys::NumPadFive);
        keys.Add(EKeys::NumPadNine);
        keys.Add(EKeys::NumPadThree);
        keys.Add(EKeys::NumPadSeven);
        keys.Add(EKeys::NumPadOne);
        return keys;
    }

    UFUNCTION()
    void OnKey(FKey Key)
    {
        HandleKey(Key, false);
    }

    UFUNCTION()
    void OnKeyRepeat(FKey Key)
    {
        HandleKey(Key, true);
    }

    bool IsKey(FKey Key, FKey A, FKey B)
    {
        return Key == A || Key == B;
    }

    void HandleKey(FKey Key, bool bRepeat)
    {
        Setup();
        if (Key == EKeys::F7)
        {
            SetOpen(!bOpen);
            return;
        }
        if (!bOpen || (Items.Num() == 0 && Key != EKeys::BackSpace))
            return;

        // a held key stops at the first / last entry; a new press goes round
        if (IsKey(Key, EKeys::Up, EKeys::NumPadEight))
            Move(-1, !bRepeat);
        else if (IsKey(Key, EKeys::Down, EKeys::NumPadTwo))
            Move(1, !bRepeat);
        else if (IsKey(Key, EKeys::PageUp, EKeys::NumPadNine))
            Move(1 - Panel.VisibleRows, false);
        else if (IsKey(Key, EKeys::PageDown, EKeys::NumPadThree))
            Move(Panel.VisibleRows - 1, false);
        else if (IsKey(Key, EKeys::Home, EKeys::NumPadSeven))
            Select(0);
        else if (IsKey(Key, EKeys::End, EKeys::NumPadOne))
            Select(Items.Num() - 1);
        else if (IsKey(Key, EKeys::Left, EKeys::NumPadFour))
            Activate(-1, bRepeat);
        else if (IsKey(Key, EKeys::Right, EKeys::NumPadSix))
            Activate(1, bRepeat);
        else if (bRepeat)
            return; // Enter and Backspace held down act once
        else if (IsKey(Key, EKeys::Enter, EKeys::NumPadFive))
            Activate(0, false);
        else if (Key == EKeys::BackSpace)
            Back();
        Refresh();
    }

    void SetOpen(bool bNewOpen)
    {
        if (bNewOpen && !EnsurePanel())
            return;
        bOpen = bNewOpen;
        if (bOpen)
        {
            if (Stack.Num() == 0)
                OpenPage(MainPage);
            else
                Rebuild();
            Refresh();
        }
        if (Panel != nullptr)
            Panel.SetVisibility(bOpen ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed);
    }

    // the viewport drops its widgets when a save is loaded, so the panel is made again then
    bool EnsurePanel()
    {
        if (Panel != nullptr && Panel.IsInViewport())
            return true;
        Panel = Cast<UCMWidget>(WidgetBlueprint::CreateWidget(UCMWidget, Gameplay::GetPlayerController(0)));
        if (Panel == nullptr)
            return false;
        Panel.LoadFonts();
        Panel.AddToViewport(1000);
        return true;
    }

    // a page opens on the entry that was selected when it was left
    void OpenPage(UCMPage Page)
    {
        Stack.Add(Page);
        Rebuild();
    }

    void Back()
    {
        if (Stack.Num() <= 1)
        {
            SetOpen(false);
            return;
        }
        Stack.RemoveAt(Stack.Num() - 1);
        Status = "";
        Rebuild();
    }

    UCMPage Current()
    {
        return Stack.Num() > 0 ? Stack[Stack.Num() - 1] : MainPage;
    }

    int Selected()
    {
        return Current().Selected;
    }

    void Select(int Index)
    {
        Current().Selected = Math::Clamp(Index, 0, Math::Max(Items.Num() - 1, 0));
    }

    void Rebuild()
    {
        Items.Reset();
        Current().Build(Items);
        Select(Selected());
    }

    // bWrap: one step past the last entry goes to the first and back; otherwise stop at the ends
    void Move(int Dir, bool bWrap)
    {
        int count = Items.Num();
        int target = Selected() + Dir;
        if (bWrap)
            target = (target + count) % count;
        Select(target);
    }

    void Activate(int Dir, bool bRepeat)
    {
        FCMItem item = Items[Selected()];
        if (item.Kind == ECMKind::Page || item.Kind == ECMKind::Action)
        {
            // Left goes back; Enter (and Right on a page) opens or runs
            if (bRepeat)
                return;
            if (Dir < 0)
                Back();
            else if (item.Kind == ECMKind::Action && Dir == 0)
                Run(item, 0);
            else if (item.Kind == ECMKind::Page && item.SubPage != nullptr)
            {
                Status = "";
                OpenPage(item.SubPage);
            }
            return;
        }
        if (item.Kind == ECMKind::Toggle)
        {
            // Enter switches; Right switches on, Left off
            bool bOn = Current().GetValue(item.Id) == CM::OnOff(true);
            if (Dir == 0 || (Dir > 0) != bOn)
                Run(item, 0);
            return;
        }
        if (item.bEnterIgnored && Dir == 0)
            return;
        Run(item, Dir == 0 ? 1 : Dir);
    }

    void Run(FCMItem Item, int Dir)
    {
        Status = Current().Activate(Item.Id, Dir);
        Rebuild();
    }

    // the titles of the pages above the current one, from the main page down
    FString Path()
    {
        FString path = "";
        for (int i = 0; i < Stack.Num() - 1; i++)
            path += (path == "" ? "" : "  /  ") + CM::T(Stack[i].GetTitle());
        return path;
    }

    void Refresh()
    {
        if (!bOpen || Panel == nullptr)
            return;
        CM::SyncLanguage();
        UCMPage page = Current();
        Panel.Title = CM::T(page.GetTitle());
        Panel.Path = Path();
        Panel.Labels.Reset();
        Panel.Values.Reset();
        Panel.IsPage.Reset();
        for (FCMItem item : Items)
        {
            Panel.Labels.Add(CM::T(item.Label));
            Panel.Values.Add(item.Kind == ECMKind::Page ? "" : CM::T(page.GetValue(item.Id)));
            Panel.IsPage.Add(item.Kind == ECMKind::Page);
        }
        int selected = Selected();
        Panel.Selected = selected;
        if (selected < Panel.First)
            Panel.First = selected;
        else if (selected >= Panel.First + Panel.VisibleRows)
            Panel.First = selected - Panel.VisibleRows + 1;
        Panel.First = Math::Clamp(Panel.First, 0, Math::Max(Items.Num() - Panel.VisibleRows, 0));
        Panel.Status = CM::T(Status);
        FString hint = page.GetHint();
        Panel.Hint = CM::T(hint != "" ? hint : "[Enter] Select   [Left/Right] Change   [Backspace] Back   [F7] Close");
        Panel.Layout();
        Panel.Repaint();
    }

    UFUNCTION()
    void OnTick()
    {
        if (CM::Hero() == nullptr)
            return;
        for (UCMPage page : MainPage.Pages)
            page.Tick(TickSeconds);
        // values such as health change on their own; keep the open page current
        if (bOpen)
            Refresh();
    }
}
