// G1R Cheat Menu: Teleport page. Known places, the markers set on the world map, the people of
// each camp, and up to ten saved positions (kept in their own save slot, so they last across games).

struct FCMPlace
{
    FString Label;
    FVector Location;
    float Yaw = 0;
}

// the teleport in progress; in the class default object so a reloaded save cannot lose it
class UCMTeleportState : UObject
{
    bool bHolding = false;
    float HoldLeft = 0;     // seconds until gravity is switched back on
    float Gravity = 1;
    FString PendingPerson;  // name key of the person to step up to once he has loaded in
    FString PendingLabel;
    int Tries = 0;
    bool bPendingGround = false; // a map marker: the ground there is searched once it has loaded
    FVector GroundAt;           // the marker's X / Y
    FVector GroundFrom;         // where the hero stood, the way back if no ground is found
}

namespace CMTeleport
{
    const float NearDistance = 8000; // 80 m: closer than this the surroundings are already loaded
    const float SkyHeight = 30000;   // above every mountain of the valley

    // the ground straight below a point, false while nothing is loaded there
    bool Ground(FVector At, FVector& OutGround)
    {
        TArray<AActor> ignore;
        AGothicCharacter hero = CM::Hero();
        if (hero != nullptr)
            ignore.Add(hero);
        FHitResult hit;
        bool found = System::LineTraceSingle(FVector(At.X, At.Y, SkyHeight + 1000), FVector(At.X, At.Y, -SkyHeight),
            UCollisionProfile::ConvertToTraceType(ECollisionChannel::ECC_Visibility), false, ignore,
            EDrawDebugTrace::None, hit, true);
        if (!found)
            return false;
        OutGround = hit.ImpactPoint;
        return true;
    }

    UCMTeleportState S()
    {
        return Cast<UCMTeleportState>(UCMTeleportState::StaticClass().GetDefaultObject());
    }

    // Far from where the hero stood, the ground is not loaded yet at the moment of arrival, so
    // gravity is switched off until the surroundings had time to load (the Teleport page's tick
    // switches it back on).
    void Hold(AGothicCharacter Hero, float Seconds)
    {
        UCharacterMovementComponent movement = Hero.CharacterMovement;
        if (movement == nullptr)
            return;
        movement.StopMovementImmediately();
        UCMTeleportState s = S();
        // a second teleport during the hold keeps the gravity the first one saved
        if (!s.bHolding)
            s.Gravity = movement.GravityScale != 0 ? movement.GravityScale : 1.0;
        movement.GravityScale = 0;
        s.bHolding = true;
        s.HoldLeft = Seconds;
    }

    void Release()
    {
        UCMTeleportState s = S();
        s.bHolding = false;
        s.PendingPerson = "";
        s.bPendingGround = false;
        AGothicCharacter hero = CM::Hero();
        if (hero != nullptr && hero.CharacterMovement != nullptr)
            hero.CharacterMovement.GravityScale = s.Gravity;
    }

    // A map point may sit at ground level while the hero's position is the middle of the body, so
    // the hero arrives a little above the point and drops. The engine refuses a spot the hero does
    // not fit into, so a few heights are tried; an exact point (a saved position) unchanged first.
    FString To(FVector Location, float Yaw, FString Name, bool bExact = false)
    {
        AGothicCharacter hero = CM::Hero();
        if (hero == nullptr)
            return CM::NotInGame;
        FVector from = hero.GetActorLocation();
        FRotator rotation = FRotator(0, Yaw, 0);
        TArray<float> lifts;
        if (bExact)
        {
            lifts.Add(0);
            lifts.Add(50);
            lifts.Add(100);
            lifts.Add(200);
        }
        else
        {
            lifts.Add(100);
            lifts.Add(200);
            lifts.Add(50);
            lifts.Add(300);
            lifts.Add(0);
        }
        bool moved = false;
        for (float lift : lifts)
        {
            if (hero.Teleport(Location + FVector(0, 0, lift), rotation))
            {
                moved = true;
                break;
            }
        }
        if (!moved)
            return "Teleport failed: no free spot at the destination";
        APlayerController pc = Gameplay::GetPlayerController(0);
        if (pc != nullptr)
            pc.SetControlRotation(rotation);
        if ((from - Location).Size() > NearDistance)
            Hold(hero, 3);
        return CM::F("Teleported: {0}", Name);
    }

    // the label of the known place closest to Location, with the distance
    FString Near(TArray<FCMPlace> Places, FVector Location)
    {
        float best = -1;
        FString label = "?";
        for (FCMPlace place : Places)
        {
            float d = (place.Location - Location).Size();
            if (best < 0 || d < best)
            {
                best = d;
                label = place.Label;
            }
        }
        return CM::T(label) + " (" + Math::RoundToInt(best / 100) + " m)";
    }
}

namespace CMNpc
{
    // Characters are told apart by their names, e.g. Character_OC_KDF_Damarok_401-WorldPointActor_Damarok:
    // before the '-' come the camp (OC / OM Old Camp and Old Mine, NC New Camp, SC Swamp Camp), the
    // guild and the name.
    TArray<FString> Tokens(FString Name)
    {
        FString left = Name;
        FString right;
        Name.Split("-", left, right);
        if (left == "")
            left = Name;
        TArray<FString> tokens;
        left.ParseIntoArray(tokens, "_", true);
        if (tokens.Num() > 0 && tokens[0] == "Character")
            tokens.RemoveAt(0);
        return tokens;
    }

    // is this the person with the name key? up to three neighbouring parts are joined, for names
    // written like Baal_Parvez or Gor_Na_Toth
    bool IsPerson(FString Name, FString Key)
    {
        TArray<FString> t = Tokens(Name);
        for (int i = 0; i < t.Num(); i++)
        {
            FString joined = "";
            for (int j = i; j < Math::Min(t.Num(), i + 3); j++)
            {
                joined += t[j].ToLower();
                if (joined == Key)
                    return true;
            }
        }
        return false;
    }

    // readable name: the game's, else the parts of the actor name that are neither camp / guild
    // codes (capitals) nor numbers
    FString DisplayName(AGothicCharacter Npc)
    {
        FString name = Npc.GetCharacterDisplayName().ToString();
        if (name != "")
            return name;
        FString result = "";
        for (FString t : Tokens(Npc.GetName().ToString()))
        {
            if (t.ToUpper() == t)
                continue;
            result += (result == "" ? "" : " ") + t;
        }
        return result != "" ? result : "?";
    }

    // the loaded characters except the hero
    TArray<AGothicCharacter> Loaded()
    {
        TArray<AGothicCharacter> result;
        AGothicCharacter hero = CM::Hero();
        TArray<AActor> actors;
        GetAllActorsOfClass(AGothicCharacter::StaticClass(), actors);
        for (AActor actor : actors)
        {
            AGothicCharacter c = Cast<AGothicCharacter>(actor);
            if (c != nullptr && c != hero)
                result.Add(c);
        }
        return result;
    }

    AGothicCharacter FindLoaded(FString Key)
    {
        for (AGothicCharacter c : Loaded())
        {
            if (IsPerson(c.GetName().ToString(), Key))
                return c;
        }
        return nullptr;
    }

    // a step in front of the person (or beside or behind when that spot is blocked), facing him
    FString StepTo(AGothicCharacter Npc, FString Label)
    {
        FVector at = Npc.GetActorLocation();
        float yaw = Npc.GetActorRotation().Yaw;
        FString msg = "";
        for (int turn = 0; turn < 360; turn += 90)
        {
            float r = (yaw + turn) * 0.0174533; // degrees to radians
            FVector spot = at + FVector(Math::Cos(r) * 150, Math::Sin(r) * 150, 0);
            msg = CMTeleport::To(spot, yaw + turn + 180, Label, true);
            if (msg.StartsWith("Teleported"))
                break;
        }
        return msg;
    }
}

// the save slot with the saved positions
class UCMSavedPositions : USaveGame
{
    UPROPERTY()
    TArray<FVector> Locations;
    UPROPERTY()
    TArray<float> Yaws;
}

class UCMMarkersPage : UCMPage
{
    UCMTeleportPage Owner;
    TArray<FVector2D> Markers;

    FString GetTitle() const override
    {
        return "Map markers";
    }

    FString GetHint() const override
    {
        return "[Enter] Teleport   [Backspace] Back   [F7] Close";
    }

    // world position of a map position; a straight fit to the game's own position readout
    FVector Approx(FVector2D M)
    {
        return FVector(227583 - 138.39 * M.X, -45351 - 131.92 * M.Y, 0);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        Markers.Reset();
        UMapData data = UMapData::GetInstance();
        if (data == nullptr || CM::Hero() == nullptr)
        {
            Items.Add(CM::Item(CM::NotInGame, ECMKind::Action, NAME_None));
            return;
        }
        // the camp maps use their own panel; only the world map's markers are listed
        FMapMarkerArrayData area = data.GetMarkersArrayFromTag(GameplayTag::Area);
        for (auto marker : area.m_MapMarkersDataArray)
            Markers.Add(marker.Key);
        if (Markers.Num() == 0)
        {
            Items.Add(CM::Item("No markers on the world map", ECMKind::Action, NAME_None));
            return;
        }
        // the newest first
        for (int i = Markers.Num() - 1; i >= 0; i--)
        {
            FVector at = Approx(Markers[i]);
            TArray<FCMPlace> places = Owner.Places;
            for (FCMPlace& place : places)
                place.Location.Z = 0;
            FString label = "" + (Markers.Num() - i) + ": " + CMTeleport::Near(places, at);
            Items.Add(CM::Item(label, ECMKind::Action, FName("Marker" + i)));
        }
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(6));
        AGothicCharacter hero = CM::Hero();
        if (!s.StartsWith("Marker") || i < 0 || i >= Markers.Num())
            return "";
        if (hero == nullptr)
            return CM::NotInGame;
        // high above the marker first; the Teleport page's tick sets the hero down on the ground
        // there once it has loaded
        FVector above = Approx(Markers[i]);
        above.Z = CMTeleport::SkyHeight;
        FVector from = hero.GetActorLocation();
        if (!hero.Teleport(above, hero.GetActorRotation()))
            return "Teleport failed";
        CMTeleport::Hold(hero, 2);
        UCMTeleportState t = CMTeleport::S();
        t.bPendingGround = true;
        t.GroundAt = above;
        t.GroundFrom = from;
        t.PendingLabel = CM::F("marker {0}", "" + (Markers.Num() - i));
        t.Tries = 0;
        return CM::F("Teleporting to marker {0}", "" + (Markers.Num() - i));
    }
}

class UCMPeopleGroupPage : UCMPage
{
    FString Title;
    TArray<FString> Names;
    TArray<FString> Keys;
    TArray<FCMPlace> Beds; // where each sleeps, from the beds in the game's map data

    FString GetTitle() const override
    {
        return Title;
    }

    FString GetHint() const override
    {
        return "[Enter] Teleport   [Backspace] Back   [F7] Close";
    }

    void Add(FString Label, FString Key, float X, float Y, float Z, float Yaw)
    {
        Names.Add(Label);
        Keys.Add(Key);
        FCMPlace bed;
        bed.Label = Label;
        bed.Location = FVector(X, Y, Z);
        bed.Yaw = Yaw;
        Beds.Add(bed);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        for (int i = 0; i < Names.Num(); i++)
            Items.Add(CM::Item(Names[i], ECMKind::Action, FName("Person" + i)));
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(6));
        if (!s.StartsWith("Person") || i < 0 || i >= Names.Num())
            return "";
        if (CM::Hero() == nullptr)
            return CM::NotInGame;
        FString key = Keys[i];
        AGothicCharacter live = CMNpc::FindLoaded(key);
        if (live != nullptr)
            return CMNpc::StepTo(live, Names[i]);
        // where the game simulates him while his area is not loaded, else his bed
        FVector target = Beds[i].Location;
        float yaw = Beds[i].Yaw;
        for (AGothicCharacterState state : UCheatModeHelper::GetAllCharactersStates())
        {
            if (state != nullptr && CMNpc::IsPerson(state.GetCharacterGlobalId().ToString(), key))
            {
                target = state.GetActorLocation();
                break;
            }
        }
        FString msg = "";
        TArray<FVector> offsets;
        offsets.Add(FVector(0, 0, 0));
        offsets.Add(FVector(120, 0, 0));
        offsets.Add(FVector(-120, 0, 0));
        offsets.Add(FVector(0, 120, 0));
        offsets.Add(FVector(0, -120, 0));
        for (FVector off : offsets)
        {
            msg = CMTeleport::To(target + off, yaw, Names[i]);
            if (msg.StartsWith("Teleported"))
                break;
        }
        if (!msg.StartsWith("Teleported"))
            return msg;
        // people nearby take a moment to load in: the Teleport page's tick looks for him again
        UCMTeleportState t = CMTeleport::S();
        if (!t.bHolding)
            CMTeleport::Hold(CM::Hero(), 1);
        t.PendingPerson = key;
        t.PendingLabel = Names[i];
        t.Tries = 0;
        return msg;
    }
}

class UCMPeoplePage : UCMPage
{
    TArray<UCMPeopleGroupPage> Groups;

    FString GetTitle() const override
    {
        return "People";
    }

    UCMPeopleGroupPage Group(FString Title)
    {
        UCMPeopleGroupPage page = Cast<UCMPeopleGroupPage>(NewObject(this, UCMPeopleGroupPage::StaticClass()));
        page.Title = Title;
        Groups.Add(page);
        return page;
    }

    void Fill()
    {
        UCMPeopleGroupPage g = Group("Old Camp");
        g.Add("Arto", "arto", 114356, -103865, -3194, 90);
        g.Add("Baal Parvez", "baalparvez", 114344, -109802, -4807, 0);
        g.Add("Balam", "balam", 112705, -100890, -3763, -91);
        g.Add("Bartholo", "bartholo", 113427, -103223, -3197, 90);
        g.Add("Bloodwyn", "bloodwyn", 112745, -100350, -3297, 0);
        g.Add("Bullit", "bullit", 110875, -100624, -3294, 180);
        g.Add("Corristo", "corristo", 109006, -103212, -4217, 90);
        g.Add("Cutter", "cutter", 111104, -100117, -3295, 1);
        g.Add("Damarok", "damarok", 109503, -103410, -4211, -90);
        g.Add("Dexter", "dexter", 111378, -107656, -5382, 149);
        g.Add("Diego", "diego", 114537, -98566, -4606, -119);
        g.Add("Drago", "drago", 109528, -103205, -4212, 90);
        g.Add("Dusty", "dusty", 113749, -109908, -4802, 0);
        g.Add("Fingers", "fingers", 110344, -100178, -4588, -3);
        g.Add("Fisk", "fisk", 112692, -106083, -5344, 88);
        g.Add("Fletcher", "fletcher", 110881, -100188, -3294, 180);
        g.Add("Gomez", "gomez", 112976, -105538, -3185, 0);
        g.Add("Gor Hanis", "gorhanis", 106151, -100555, -5370, -125);
        g.Add("Graham", "graham", 119918, -99311, -4410, 96);
        g.Add("Gravo", "gravo", 116916, -99448, -4988, -177);
        g.Add("Grim", "grim", 115116, -97732, -4643, 115);
        g.Add("Guy", "guy", 105148, -96224, -4832, 115);
        g.Add("Herek", "herek", 117410, -108626, -4391, 0);
        g.Add("Huno", "huno", 105165, -101994, -4563, -7);
        g.Add("Jackal", "jackal", 110892, -99719, -3294, 180);
        g.Add("Jesse", "jesse", 118088, -108383, -4407, -73);
        g.Add("Kharim", "kharim", 108705, -99971, -5283, 10);
        g.Add("Kirgo", "kirgo", 107418, -101068, -5257, 15);
        g.Add("Kyle", "kyle", 119218, -105176, -4526, 92);
        g.Add("Milten", "milten", 108611, -103158, -4218, 0);
        g.Add("Mordrag", "mordrag", 109303, -105696, -5219, -2);
        g.Add("Mud", "mud", 112024, -98967, -4962, -4);
        g.Add("Omid", "omid", 112687, -100666, -3760, 94);
        g.Add("Raven", "raven", 115101, -105550, -3184, 0);
        g.Add("Rodriguez", "rodriguez", 108255, -103224, -4217, 90);
        g.Add("Scar", "scar", 112964, -103618, -3194, 90);
        g.Add("Scatty", "scatty", 109804, -99305, -4848, 90);
        g.Add("Scorpio", "scorpio", 112731, -100947, -3296, 0);
        g.Add("Skip", "skip", 108925, -100870, -3269, 15);
        g.Add("Sly", "sly", 119949, -102237, -4365, -94);
        g.Add("Snaf", "snaf", 111421, -98947, -5004, 0);
        g.Add("Stone", "stone", 112517, -100420, -3298, -180);
        g.Add("Syra", "syra", 116822, -104934, -3872, -30);
        g.Add("Thorus", "thorus", 114364, -103266, -3200, 90);
        g.Add("Torrez", "torrez", 108286, -103328, -4220, -90);
        g.Add("Whistler", "whistler", 116326, -107239, -5027, -87);

        g = Group("New Camp");
        g.Add("Blade", "blade", 178995, -97258, -1426, 178);
        g.Add("Bruce", "bruce", 175157, -100870, -808, 80);
        g.Add("Buster", "buster", 175199, -100549, -467, -8);
        g.Add("Butch", "butch", 176560, -100155, -1430, -123);
        g.Add("Cipher", "cipher", 174164, -99935, -1157, -139);
        g.Add("Cord", "cord", 179395, -98656, -455, 166);
        g.Add("Cronos", "cronos", 179777, -100090, 647, 60);
        g.Add("Gorn", "gorn", 178693, -96274, -1440, 48);
        g.Add("Homer", "homer", 177323, -100443, -1418, -109);
        g.Add("Horatio", "horatio", 163762, -86374, -1617, 20);
        g.Add("Jeremiah", "jeremiah", 177262, -86560, 286, 170);
        g.Add("Lares", "lares", 173464, -101145, -291, -55);
        g.Add("Lee", "lee", 183111, -97563, -297, -89);
        g.Add("Lefty", "lefty", 164392, -85777, -630, 114);
        g.Add("Merdarion", "merdarion", 178613, -101934, 644, -85);
        g.Add("Myxir", "myxir", 180963, -101151, 650, 120);
        g.Add("Nefarius", "nefarius", 180133, -103216, 650, -165);
        g.Add("Orik", "orik", 180398, -98948, -285, 69);
        g.Add("Pock", "pock", 160337, -87066, -1308, -160);
        g.Add("Riordian", "riordian", 178781, -102482, 643, -160);
        g.Add("Rufus", "rufus", 164665, -86051, -1630, -162);
        g.Add("Saturas", "saturas", 180793, -102411, 643, 12);
        g.Add("Sharky", "sharky", 175437, -99244, -1178, 43);
        g.Add("Shrike", "shrike", 175822, -96106, -1563, -117);
        g.Add("Silas", "silas", 177393, -86587, 290, -8);
        g.Add("Torlof", "torlof", 180239, -97793, -581, 180);
        g.Add("Wedge", "wedge", 177047, -101369, -1012, 172);
        g.Add("Wolf", "wolf", 177424, -102030, -312, -2);

        g = Group("Swamp Camp");
        g.Add("Baal Cadar", "baalcadar", 42798, -119459, -8774, -112);
        g.Add("Baal Namib", "baalnamib", 49404, -118756, -8777, -126);
        g.Add("Baal Orun", "baalorun", 47162, -121507, -8852, 114);
        g.Add("Baal Tondral", "baaltondral", 45110, -119404, -7325, -145);
        g.Add("Balor", "balor", 54276, -135932, -7476, 165);
        g.Add("Caine", "caine", 45822, -124076, -8802, -170);
        g.Add("Chani", "chani", 50440, -104722, -8204, 50);
        g.Add("Cor Angar", "corangar", 43268, -118419, -6946, -26);
        g.Add("Cor Kalom", "corkalom", 42327, -116172, -7546, 24);
        g.Add("Darrion", "darrion", 45506, -117844, -8602, -79);
        g.Add("Dusty", "dusty", 42007, -119166, -6929, 84);
        g.Add("Fortuno", "fortuno", 45192, -118607, -7845, 128);
        g.Add("Ghorim", "ghorim", 47132, -121469, -7867, 160);
        g.Add("Gor Na Toth", "gornatoth", 45894, -119118, -7771, 15);
        g.Add("Joru", "joru", 43881, -116775, -8623, 90);
        g.Add("Melvin", "melvin", 46485, -123985, -8813, 10);
        g.Add("Natalia", "natalia", 52226, -106205, -8187, 50);
        g.Add("Nyras", "nyras", 42298, -119140, -7476, 140);
        g.Add("Shrat", "shrat", 45287, -138405, -8659, 62);
        g.Add("Viran", "viran", 44815, -120925, -7044, 40);
        g.Add("Yberion", "yberion", 52536, -104449, -8071, -41);

        g = Group("Outside the camps");
        g.Add("Aidan", "aidan", 142827, -98909, -3942, -6);
        g.Add("Cavalorn", "cavalorn", 128315, -97082, -5258, 142);
        g.Add("Cohsel", "cohsel", 134084, -102294, -4083, 91);
        g.Add("Drax", "drax", 118620, -83338, -4927, 110);
        g.Add("Gilbert", "gilbert", 118297, -116395, -2697, -53);
        g.Add("Muk", "muk", 140195, -136652, 131, 180);
        g.Add("Quentin", "quentin", 125356, -65231, 2674, 134);
        g.Add("Ratford", "ratford", 118768, -83504, -4939, -98);
        g.Add("Swiney", "swiney", 163845, -122622, 2886, -41);
        g.Add("Xardas", "xardas", 126738, -143243, 4355, 180);
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Groups.Num() == 0)
            Fill();
        for (UCMPeopleGroupPage page : Groups)
            Items.Add(CM::PageItem(page.Title, page));
    }
}

class UCMSavedPage : UCMPage
{
    UCMTeleportPage Owner;
    UCMSavedPositions Saved;
    const FString Slot = "Kandro78-G1RCheatMenu-Positions";
    const int MaxSaved = 10;

    FString GetTitle() const override
    {
        return "Saved positions";
    }

    FString GetHint() const override
    {
        return "[Enter] Save / Teleport   [Left] Delete   [Backspace] Back";
    }

    UCMSavedPositions Load()
    {
        if (Saved == nullptr)
            Saved = Cast<UCMSavedPositions>(Gameplay::LoadGameFromSlot(Slot, 0));
        if (Saved == nullptr)
            Saved = Cast<UCMSavedPositions>(Gameplay::CreateSaveGameObject(UCMSavedPositions::StaticClass()));
        return Saved;
    }

    int Count()
    {
        return Load().Locations.Num();
    }

    void Build(TArray<FCMItem>& Items) override
    {
        UCMSavedPositions saved = Load();
        Items.Add(CM::Item("Save current position", ECMKind::Action, n"Save"));
        for (int i = 0; i < saved.Locations.Num(); i++)
        {
            FString label = "" + (i + 1) + ": " + CMTeleport::Near(Owner.Places, saved.Locations[i]);
            Items.Add(CM::Item(label, ECMKind::Value, FName("Saved" + i)));
        }
    }

    FString Activate(FName Id, int Dir) override
    {
        UCMSavedPositions saved = Load();
        AGothicCharacter hero = CM::Hero();
        if (Id == n"Save")
        {
            if (hero == nullptr)
                return CM::NotInGame;
            if (saved.Locations.Num() >= MaxSaved)
                return CM::F("All {0} slots are used. Delete one first", "" + MaxSaved);
            saved.Locations.Add(hero.GetActorLocation());
            saved.Yaws.Add(hero.GetActorRotation().Yaw);
            if (!Gameplay::SaveGameToSlot(saved, Slot, 0))
                return "Saved for this session only: the slot could not be written";
            return CM::F("Position saved as number {0}", "" + saved.Locations.Num());
        }
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(5));
        if (!s.StartsWith("Saved") || i < 0 || i >= saved.Locations.Num())
            return "";
        if (Dir < 0)
        {
            saved.Locations.RemoveAt(i);
            saved.Yaws.RemoveAt(i);
            Gameplay::SaveGameToSlot(saved, Slot, 0);
            return "Saved position deleted";
        }
        return CMTeleport::To(saved.Locations[i], saved.Yaws[i], CM::F("saved position {0}", "" + (i + 1)), true);
    }
}

class UCMTeleportPage : UCMPage
{
    TArray<FCMPlace> Places;
    UCMMarkersPage Markers;
    UCMPeoplePage People;
    UCMSavedPage Saved;

    FString GetTitle() const override
    {
        return "Teleport";
    }

    void Add(FString Label, float X, float Y, float Z, float Yaw)
    {
        FCMPlace place;
        place.Label = Label;
        place.Location = FVector(X, Y, Z);
        place.Yaw = Yaw;
        Places.Add(place);
    }

    // Standing points from the game's own map data (G1R\Script\Map\MainMap\InteractionSpots.json);
    // world units (1 unit = 1 cm), yaw is the facing in degrees
    void Fill()
    {
        Add("Exchange place (game start)", 103662, -58232, 2427, -76);
        Add("Abandoned mine: entrance", 105219, -69218, 2226, -128);
        Add("Old Camp: main gate", 118913, -96446, -5224, 59);
        Add("Old Camp: second gate", 106902, -108145, -4701, 59);
        Add("Old Camp: Fire Mages", 110420, -104999, -3003, 0);
        Add("Old Mine: entrance area", 147464, -69762, -3585, -21);
        Add("New Camp: entrance", 158959, -95041, -2550, 58);
        Add("New Camp: tavern", 176009, -88039, -3, 0);
        Add("New Camp: Water Mages", 183854, -103449, 155, 0);
        Add("Free Mine: camp gate", 167208, -125385, 418, -24);
        Add("Swamp Camp: entrance", 52381, -114515, -8902, -24);
        Add("Swamp Camp: temple square", 45203, -112685, -8816, 51);
        Add("Xardas' tower", 124303, -142828, 1523, 0);
        Add("Sunken tower", 106736, -134991, 2505, 0);
        Add("Stonehenge", 153087, -116414, -249, 0);
        Add("Monastery ruins", 78222, -63368, -4735, 0);
        Add("Castle ruins", 105191, -126969, 5543, 0);
        Add("Harpy tower", 83680, -143848, 5381, 0);
        Add("Troll canyon", 129389, -66133, 402, 0);
        Add("Lighthouse", 74928, -85364, -3196, 0);
        Add("Smugglers", 62390, -95777, -8840, 0);
        Add("Nyras' focus stone", 48207, -102959, -3688, 0);
        Add("Orc cemetery", 77470, -124893, -403, -3);
        Add("Orc town: bridge", 131287, -127000, -846, 0);
        Add("Sleeper temple: entrance", 155822, -144785, -596, 0);
        Add("Tundra: Innos temple", 154257, -53619, 4031, 0);
        Add("Tundra: plateau", 167926, -62466, 2086, 0);
        Add("Tundra: waterfall", 157253, -70079, -2627, 26);

        Markers = Cast<UCMMarkersPage>(NewObject(this, UCMMarkersPage::StaticClass()));
        Markers.Owner = this;
        People = Cast<UCMPeoplePage>(NewObject(this, UCMPeoplePage::StaticClass()));
        Saved = Cast<UCMSavedPage>(NewObject(this, UCMSavedPage::StaticClass()));
        Saved.Owner = this;
    }

    void Build(TArray<FCMItem>& Items) override
    {
        if (Places.Num() == 0)
            Fill();
        Items.Add(CM::PageItem("Map markers", Markers));
        Items.Add(CM::PageItem("People", People));
        Items.Add(CM::PageItem("Saved positions", Saved));
        for (int i = 0; i < Places.Num(); i++)
            Items.Add(CM::Item(Places[i].Label, ECMKind::Action, FName("Place" + i)));
    }

    FString Activate(FName Id, int Dir) override
    {
        FString s = Id.ToString();
        int i = String::Conv_StringToInt(s.RightChop(5));
        if (!s.StartsWith("Place") || i < 0 || i >= Places.Num())
            return "";
        return CMTeleport::To(Places[i].Location, Places[i].Yaw, Places[i].Label);
    }

    // the teleport hold: gravity back on once the ground had time to load; a person teleported
    // to is looked for again for a few seconds and stepped up to when he has loaded in
    void Tick(float DeltaSeconds) override
    {
        UCMTeleportState s = CMTeleport::S();
        if (!s.bHolding)
            return;
        s.HoldLeft -= DeltaSeconds;
        if (s.HoldLeft > 0)
            return;
        if (s.bPendingGround)
        {
            FVector ground;
            if (CMTeleport::Ground(s.GroundAt, ground))
            {
                FString label = s.PendingLabel;
                CMTeleport::Release();
                CMTeleport::To(ground, CM::Hero() != nullptr ? CM::Hero().GetActorRotation().Yaw : 0, label);
                return;
            }
            s.Tries++;
            if (s.Tries <= 8)
            {
                s.HoldLeft = 1;
                return;
            }
            // nothing to stand on (a marker outside the valley): back to where he came from
            FVector back = s.GroundFrom;
            CMTeleport::Release();
            CMTeleport::To(back, 0, "start (no ground at the marker)", true);
            return;
        }
        if (s.PendingPerson != "")
        {
            AGothicCharacter found = CMNpc::FindLoaded(s.PendingPerson);
            if (found != nullptr)
            {
                FString label = s.PendingLabel;
                CMTeleport::Release();
                CMNpc::StepTo(found, label);
                return;
            }
            // the ground has loaded by now: the hero may stand while the search goes on
            AGothicCharacter hero = CM::Hero();
            if (hero != nullptr && hero.CharacterMovement != nullptr)
                hero.CharacterMovement.GravityScale = s.Gravity;
            s.Tries++;
            if (s.Tries <= 5)
            {
                s.HoldLeft = 1;
                return;
            }
        }
        CMTeleport::Release();
    }
}
