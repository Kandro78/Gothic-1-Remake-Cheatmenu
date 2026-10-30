// G1R Cheat Menu: Achievements page. Unlocks are permanent on the player's account. Ids as declared
// in the game's Story/Achievements script. The console command gothic.achievement.Unlock is a cheat
// command and is refused in the shipping game, so the page calls the achievement subsystem's native
// UnlockAchievement instead: it is not exposed to script, but a delegate bound by name reaches it,
// and unlike the subsystem's progress update it does not stop when mods are loaded.
delegate void FCMUnlockAchievement(FString AchievementId);

class UCMAchievementsPage : UCMPage
{
    TArray<FString> Ids;
    TArray<FString> Labels;
    float64 AllArmedAt = -100; // "Unlock ALL" asks for a second Enter within 5 seconds

    FString GetTitle() const override
    {
        return "Achievements";
    }

    FString GetHint() const override
    {
        return "[Enter] Unlock (permanent)   [Backspace] Back   [F7] Close";
    }

    void Add(FString Id, FString Label)
    {
        Ids.Add(Id);
        Labels.Add(Label);
    }

    void Fill()
    {
        Add("ACH_STORY_01", "Complete chapter 2");
        Add("ACH_STORY_02", "Complete chapter 3");
        Add("ACH_STORY_03", "Complete chapter 4");
        Add("ACH_STORY_04", "Complete chapter 5");
        Add("ACH_STORY_05", "Complete chapter 6");
        Add("ACH_STORY_06", "Enter the Sleeper Temple");
        Add("ACH_Story_07", "Learn Orcish level 2");
        Add("ACH_Story_08", "Complete the 'Escape Plan' quest");
        Add("ACH_Story_09", "Complete Cavalorn's book quests");
        Add("ACH_Story_10", "Complete the Chromanin quests");
        Add("ACH_Story_11", "Spare Gomez's life");
        Add("ACH_Camp_01", "Join the Old Camp");
        Add("ACH_Camp_02", "Join the New Camp");
        Add("ACH_Camp_03", "Join the Swamp Camp");
        Add("ACH_Rank_01", "Rank up in any guild");
        Add("ACH_Maps_01", "Get all maps");
        Add("ACH_Weapons_01", "Master all melee weapons");
        Add("ACH_Weapons_02", "Master all ranged weapons");
        Add("ACH_Mage_01", "Reach the 6th magic circle");
        Add("ACH_Mage_02", "Transform into all creatures");
        Add("ACH_Mage_03", "3 elemental damage types on one enemy");
        Add("ACH_Armor_01", "Get the ore armor");
        Add("ACH_Armor_02", "Get all mods for an armor");
        Add("ACH_Thief_01", "Pickpocket 20 characters");
        Add("ACH_Thief_02", "Pick 20 locks");
        Add("ACH_Crafter_01", "Craft your first item");
        Add("ACH_Crafter_02", "Craft 5 weapons");
        Add("ACH_Crafter_03", "Craft 10 potions");
        Add("ACH_Crafter_04", "Craft a scroll");
        Add("ACH_Fight_01", "Defeat 10 enemies with your fists");
        Add("ACH_Fight_02", "Parry 5 times without taking damage");
        Add("ACH_Ranged_01", "Kill 10 enemies by headshot");
        Add("ACH_Teacher_01", "Learn all lessons");
        Add("ACH_Funny_01", "Exhaust all of Mud's dialogue");
        Add("ACH_Funny_02", "Kill an enemy by falling damage");
        Add("ACH_Hidden_01", "Read 10 books");
        Add("ACH_Secret_01", "Sneak into the Old Camp from chapter 4");
        Add("ACH_Secret_02", "Visit Xardas' room");
        Add("ACH_Challenge_01", "Finish the game without sleeping");
        Add("ACH_Challenge_02", "Finish the game in permadeath mode");
        Add("ACH_All", "Get all achievements");
        Add("ACH_AllPlus", "Get all achievements (plus)");
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Ids.Num() == 0)
            Fill();
        Items.Add(CM::Item("Unlock ALL achievements", ECMKind::Action, n"All"));
        for (int i = 0; i < Ids.Num(); i++)
            Items.Add(CM::Item(Labels[i], ECMKind::Action, FName("Ach" + i)));
    }

    bool Unlock(FString Id)
    {
        UGothicAchievementSubsystem sub = UGothicAchievementSubsystem::Get(CM::Hero());
        if (sub == nullptr)
            return false;
        FCMUnlockAchievement d;
        d.BindUFunction(sub, n"UnlockAchievement");
        if (!d.IsBound())
            return false;
        d.Execute(Id);
        return true;
    }

    FString Activate(FName Id, int Dir) override
    {
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        if (Id == n"All")
        {
            float64 now = Gameplay::GetRealTimeSeconds();
            if (now - AllArmedAt > 5)
            {
                AllArmedAt = now;
                return "Permanent on your account. Enter again to confirm";
            }
            AllArmedAt = -100;
            int sent = 0;
            for (FString id : Ids)
            {
                if (Unlock(id))
                    sent++;
            }
            return CM::F("Unlock sent for {0} of {1} achievements", "" + sent, "" + Ids.Num());
        }
        AllArmedAt = -100;
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(3));
        if (!s.StartsWith("Ach") || i < 0 || i >= Ids.Num())
            return "";
        return Unlock(Ids[i]) ? CM::F("Unlock sent: {0}", Labels[i]) : CM::F("Unlock failed: {0}", Ids[i]);
    }
}
