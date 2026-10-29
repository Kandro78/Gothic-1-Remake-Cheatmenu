// G1R Cheat Menu: Quests page. The failed and the running quests, read from the game each time a
// list opens and after every change (completing a quest moves it out of the list). Marking a quest
// as succeeded runs the game's own success handling, but no dialogue and no reward that would
// normally lead up to it.

class UCMQuestListPage : UCMPage
{
    FString Title;
    EQuestState State = EQuestState::Running;
    FString EmptyText;
    TArray<UQuest> Quests;

    FString GetTitle() const override
    {
        return Title;
    }

    FString GetHint() const override
    {
        if (State == EQuestState::Failed)
            return "[Enter] Complete   [Left] Restart   [Backspace] Back";
        return "[Enter] Mark as completed (save first)   [Backspace] Back";
    }

    FString QuestName(UQuest Quest)
    {
        FString text = Quest.GetQuestDisplayName().ToString();
        if (text != "")
            return text;
        return Quest.GetClass().GetName().ToString().Replace("Quest_", "").Replace("_", " ");
    }

    // main quests first, then objectives, each sorted by name. Quests the quest log never shows
    // (glossary entries, tutorials, chapter markers) have no display name ("[Unnamed ...]").
    void Build(TArray<FCMItem>& Items) override
    {
        Quests.Reset();
        UQuestSubsystem sub = UQuestSubsystem::Get();
        if (sub == nullptr || CM::Hero() == nullptr)
        {
            Items.Add(CM::Item(CM::NotInGame, ECMKind::Action, NAME_None));
            return;
        }
        TArray<FString> mainKeys;
        TArray<FString> objectiveKeys;
        TArray<UQuest> found = sub.GetAllQuestsInState(State);
        for (int i = 0; i < found.Num(); i++)
        {
            UQuest q = found[i];
            if (q == nullptr)
                continue;
            FString label = QuestName(q);
            if (label.StartsWith("[Unnamed"))
                continue;
            if (q.IsPartOfSubobjective())
                objectiveKeys.Add("- " + label + "\t" + i);
            else
                mainKeys.Add(label + "\t" + i);
        }
        mainKeys.Sort();
        objectiveKeys.Sort();
        mainKeys.Append(objectiveKeys);
        for (FString key : mainKeys)
        {
            FString label;
            FString index;
            key.Split("\t", label, index, ESearchCase::CaseSensitive, ESearchDir::FromEnd);
            Quests.Add(found[String::Conv_StringToInt(index)]);
            ECMKind kind = State == EQuestState::Failed ? ECMKind::Value : ECMKind::Action;
            Items.Add(CM::Item(label, kind, FName("Quest" + (Quests.Num() - 1))));
        }
        if (Quests.Num() == 0)
            Items.Add(CM::Item(EmptyText, ECMKind::Action, NAME_None));
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(5));
        if (!s.StartsWith("Quest") || i < 0 || i >= Quests.Num())
            return "";
        AGothicCharacter hero = CM::Hero();
        UQuest quest = Quests[i];
        if (hero == nullptr)
            return CM::NotInGame;
        if (quest == nullptr)
            return "Quest no longer available";
        return Dir < 0 ? Restart(hero, quest) : Complete(hero, quest);
    }

    FString Complete(AGothicCharacter Hero, UQuest Quest)
    {
        FString name = QuestName(Quest);
        // a failed quest is set running again first: the game only succeeds a quest that is running
        if (Quest.GetState() == EQuestState::Failed)
            Quest.RestartQuest(Hero);
        Quest.SucceedQuest(Hero);
        if (Quest.GetState() == EQuestState::Succeeded)
            return CM::F("Quest completed: {0}", name);
        return CM::F("Could not complete: {0}", name);
    }

    // sets a failed quest running again, so it can still be played the normal way
    FString Restart(AGothicCharacter Hero, UQuest Quest)
    {
        FString name = QuestName(Quest);
        // the game fails a quest again on its next check while its fail condition still holds
        // (someone it needs has died, its chapter is over, ...): such a quest is left alone
        if (Quest.ShouldFail())
            return CM::F("Would fail again at once: {0}", name);
        // a sub-task of a failed quest fails again at once: the quest it belongs to restarts first
        UQuest parent = Quest.GetParentQuest();
        if (parent != nullptr && parent.GetState() == EQuestState::Failed)
            parent.RestartQuest(Hero);
        Quest.RestartQuest(Hero);
        if (Quest.GetState() != EQuestState::Running)
            return CM::F("Could not restart: {0}", name);
        if (Quest.ShouldFail())
            return CM::F("Would fail again at once: {0}", name);
        return CM::F("Quest restarted: {0}", name);
    }
}

class UCMQuestsPage : UCMPage
{
    UCMQuestListPage Failed;
    UCMQuestListPage Running;

    FString GetTitle() const override
    {
        return "Quests";
    }

    UCMQuestListPage List(FString Title, EQuestState State, FString EmptyText)
    {
        UCMQuestListPage page = Cast<UCMQuestListPage>(NewObject(this, UCMQuestListPage::StaticClass()));
        page.Title = Title;
        page.State = State;
        page.EmptyText = EmptyText;
        return page;
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Failed == nullptr)
        {
            Failed = List("Failed quests", EQuestState::Failed, "No failed quests");
            Running = List("Running quests", EQuestState::Running, "No running quests");
        }
        Items.Add(CM::PageItem("Failed quests", Failed));
        Items.Add(CM::PageItem("Running quests", Running));
    }
}
