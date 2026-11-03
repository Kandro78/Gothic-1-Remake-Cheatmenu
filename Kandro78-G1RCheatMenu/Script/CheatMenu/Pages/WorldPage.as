// G1R Cheat Menu: World page. Time of day, freezing time, day speed, weather, game speed and the story chapter.

// switches that last for the whole game session, like UCMPlayerState
class UCMWorldState : UObject
{
    bool bFrozen = false;
    float Speed = 1;
    float FastSpeed = 3; // what the game speed key switches to: the last speed above or below 1x
    float DaySpeed = 1;
}

class UCMWorldPage : UCMPage
{
    float RefreezeTimer = 0.0;

    UCMWorldState S() const
    {
        return Cast<UCMWorldState>(UCMWorldState::StaticClass().GetDefaultObject());
    }

    FString GetTitle() const override
    {
        return "World";
    }

    void Build(TArray<FCMItem>& Items) override
    {
        Items.Add(CM::Item("Time (1 hour steps)", ECMKind::Value, n"Time"));
        Items.Add(CM::Item("Freeze time", ECMKind::Toggle, n"Freeze"));
        Items.Add(CM::Item("Day speed", ECMKind::Value, n"DaySpeed"));
        Items.Add(CM::Item("Weather", ECMKind::Value, n"Weather"));
        Items.Add(CM::Item("Game speed", ECMKind::Value, n"Speed"));
        // changing the chapter is hard to undo: only Left / Right change it, Enter does nothing
        FCMItem chapter = CM::Item("Story chapter", ECMKind::Value, n"Chapter");
        chapter.bEnterIgnored = true;
        Items.Add(chapter);
    }

    FString Clock()
    {
        UGameTimeSubsystem time = UGameTimeSubsystem::Get();
        if (time == nullptr || CM::Hero() == nullptr)
            return "-";
        int day = Math::FloorToInt(time.GetCurrentGameTime().TotalSeconds / 86400);
        FClockTime clock = time.GetCurrentClockTime();
        FString minute = "" + clock.Minute;
        if (minute.Len() < 2)
            minute = "0" + minute;
        FString hour = "" + clock.Hour;
        if (hour.Len() < 2)
            hour = "0" + hour;
        return CM::F("Day {0}, {1}:{2}", "" + day, hour, minute);
    }

    AGothicUltraDynamicController Weather()
    {
        TArray<AActor> actors;
        GetAllActorsOfClass(AGothicUltraDynamicController::StaticClass(), actors);
        return actors.Num() > 0 ? Cast<AGothicUltraDynamicController>(actors[0]) : nullptr;
    }

    // the weathers in the order Left / Right go through them
    TArray<EWeather> Weathers()
    {
        TArray<EWeather> list;
        list.Add(EWeather::Sunny);
        list.Add(EWeather::Cloudy);
        list.Add(EWeather::Rain_Level1);
        list.Add(EWeather::Rain_Level2);
        list.Add(EWeather::Rain_Level3);
        return list;
    }

    FString WeatherName(EWeather Weather)
    {
        if (Weather == EWeather::Sunny)
            return "Sunny";
        if (Weather == EWeather::Cloudy)
            return "Cloudy";
        if (Weather == EWeather::Rain_Level1)
            return "Light rain";
        if (Weather == EWeather::Rain_Level2)
            return "Rain";
        if (Weather == EWeather::Rain_Level3)
            return "Storm";
        return "-";
    }

    TArray<float> Speeds()
    {
        TArray<float> list;
        list.Add(0.25);
        list.Add(0.5);
        list.Add(1);
        list.Add(2);
        list.Add(3);
        list.Add(5);
        return list;
    }

    TArray<float> DaySpeeds()
    {
        TArray<float> list;
        list.Add(0.25);
        list.Add(0.5);
        list.Add(1);
        list.Add(2);
        list.Add(4);
        list.Add(8);
        list.Add(16);
        list.Add(32);
        list.Add(64);
        list.Add(128);
        return list;
    }

    // the game speed key: switches between 1x and the last other game speed (3x at first)
    FString ToggleSpeed()
    {
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        UCMWorldState s = S();
        s.Speed = s.Speed != 1 ? 1 : s.FastSpeed;
        Gameplay::SetGlobalTimeDilation(s.Speed);
        return CM::F("Game speed: {0}x", CM::Num(s.Speed));
    }

    // where Current is in List, the 1x entry when it is not there
    int StepIndex(TArray<float> List, float Current)
    {
        int idx = List.FindIndex(Current);
        return idx >= 0 ? idx : List.FindIndex(1);
    }

    FString GetValue(FName Id) override
    {
        if (Id == n"Time")
            return Clock();
        if (Id == n"Freeze")
            return CM::OnOff(S().bFrozen);
        if (Id == n"Weather")
        {
            AGothicUltraDynamicController ctrl = Weather();
            return ctrl != nullptr ? WeatherName(ctrl.GetCurrentWeather()) : "-";
        }
        if (Id == n"Speed")
            return CM::Num(S().Speed) + "x";
        if (Id == n"DaySpeed")
            return CM::Num(S().DaySpeed) + "x";
        if (Id == n"Chapter")
        {
            UGameStory story = UGameStory::GetMainStory();
            return story != nullptr && CM::Hero() != nullptr ? "" + story.GetChapter() : "-";
        }
        return "";
    }

    FString Activate(FName Id, int Dir) override
    {
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        if (Id == n"Time")
            return ShiftTime(Dir);
        if (Id == n"Freeze")
        {
            UGameTimeSubsystem time = UGameTimeSubsystem::Get();
            if (time == nullptr)
                return CM::NotInGame;
            S().bFrozen = !S().bFrozen;
            if (S().bFrozen)
                time.FreezeTime();
            else if (S().DaySpeed >= 1) // a slow day keeps the clock frozen and moves it itself
                time.UnfreezeTime();
            return S().bFrozen ? "Time frozen" : "Time running";
        }
        if (Id == n"DaySpeed")
        {
            UGameTimeSubsystem time = UGameTimeSubsystem::Get();
            if (time == nullptr)
                return CM::NotInGame;
            TArray<float> list = DaySpeeds();
            int idx = StepIndex(list, S().DaySpeed);
            bool wasSlow = S().DaySpeed < 1;
            S().DaySpeed = list[Math::Clamp(idx + Dir, 0, list.Num() - 1)];
            bool slow = S().DaySpeed < 1;
            if (!S().bFrozen && slow != wasSlow)
            {
                if (slow)
                    time.FreezeTime();
                else
                    time.UnfreezeTime();
            }
            return CM::F("Day speed: {0}x", CM::Num(S().DaySpeed));
        }
        if (Id == n"Weather")
        {
            AGothicUltraDynamicController ctrl = Weather();
            if (ctrl == nullptr)
                return "Weather controller not found";
            TArray<EWeather> list = Weathers();
            int idx = Math::Max(list.FindIndex(ctrl.GetCurrentWeather()), 0);
            EWeather next = list[(idx + Dir + list.Num()) % list.Num()];
            ctrl.SetCurrentWeatherImmediate(next);
            return CM::F("Weather: {0}", WeatherName(next));
        }
        if (Id == n"Speed")
        {
            TArray<float> list = Speeds();
            int idx = StepIndex(list, S().Speed);
            S().Speed = list[Math::Clamp(idx + Dir, 0, list.Num() - 1)];
            if (S().Speed != 1)
                S().FastSpeed = S().Speed;
            Gameplay::SetGlobalTimeDilation(S().Speed);
            return CM::F("Game speed: {0}x", CM::Num(S().Speed));
        }
        if (Id == n"Chapter")
        {
            UGameStory story = UGameStory::GetMainStory();
            if (story == nullptr)
                return CM::NotInGame;
            int cur = story.GetChapter();
            int target = Math::Clamp(cur + Dir, 1, 6);
            if (target == cur)
                return CM::F("Chapter: {0}", "" + cur);
            story.ChangeChapter(target);
            return CM::F("Chapter: {0} -> {1}", "" + cur, "" + story.GetChapter());
        }
        return "";
    }

    // Day speed: the clock runs GameTimeSpeed in-game seconds per second (15 in the world settings)
    // and has no setter for it. Faster days skip the extra time every tick; slower days keep the
    // clock frozen and move it forward by the shorter step. A frozen clock (Freeze time or a slow
    // day) is frozen again every second, as the game unfreezes it itself after dialogues and
    // cutscenes.
    void Tick(float DeltaSeconds) override
    {
        UCMWorldState s = S();
        // a loaded save is a new world, which starts at 1x
        if (s.Speed != 1 && Gameplay::GetGlobalTimeDilation() != s.Speed)
            Gameplay::SetGlobalTimeDilation(s.Speed);
        if (!s.bFrozen && s.DaySpeed == 1)
            return;
        UGameTimeSubsystem time = UGameTimeSubsystem::Get();
        if (time == nullptr)
            return;
        RefreezeTimer += DeltaSeconds;
        bool refreeze = RefreezeTimer >= 1.0;
        if (refreeze)
        {
            RefreezeTimer = 0;
            if (s.bFrozen || s.DaySpeed < 1)
                time.FreezeTime();
        }
        if (s.bFrozen)
            return;
        float base = 15.0;
        AGothicWorldSettings settings = AGothicWorldSettings::Get();
        if (settings != nullptr && settings.GameTimeConfig != nullptr && settings.GameTimeConfig.GameTimeSpeed > 0)
            base = settings.GameTimeConfig.GameTimeSpeed;
        if (s.DaySpeed < 1)
            time.SkipTime(FInGameTime::FromSeconds(DeltaSeconds * base * s.DaySpeed));
        else
            time.SkipTime(FInGameTime::FromSeconds(DeltaSeconds * base * (s.DaySpeed - 1)));
    }

    FString ShiftTime(int Dir)
    {
        UGameTimeSubsystem time = UGameTimeSubsystem::Get();
        if (time == nullptr)
            return CM::NotInGame;
        if (Dir > 0)
        {
            time.SkipTime(FInGameTime::FromHours(1));
        }
        else
        {
            float64 total = time.GetCurrentGameTime().TotalSeconds;
            if (total < 3600)
                return "Cannot go back before day 0";
            total -= 3600;
            int day = Math::FloorToInt(total / 86400);
            float64 rest = total - day * 86400.0;
            int hour = Math::FloorToInt(rest / 3600);
            int minute = Math::FloorToInt((rest - hour * 3600.0) / 60);
            time.SetCurrentGameTime(day, hour, minute, 0);
        }
        return CM::F("Time: {0}", Clock());
    }
}
