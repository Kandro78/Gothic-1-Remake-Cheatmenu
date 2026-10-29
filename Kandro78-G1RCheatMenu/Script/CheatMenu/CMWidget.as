// G1R Cheat Menu: the menu panel. A script widget without a widget blueprint, painted in OnPaint.
// The look follows the game's settings screen like the UE4SS versions: near-black backdrop, pale
// salmon block-letter title over a grey hairline, serif rows in warm off-white with copper values,
// the selected row as a pale salmon plate with dark text. Fonts are the game's own.

class UCMWidget : UUserWidget
{
    UPROPERTY()
    UFont BodyFont;
    UPROPERTY()
    UFont TitleFont;

    // filled by the menu before every repaint
    FString Title;
    FString Path; // the pages above this one
    TArray<FString> Labels;
    TArray<FString> Values;
    TArray<bool> IsPage;
    int Selected = 0;
    int First = 0; // first visible row
    FString Hint;
    FString Status;

    // layout in slate units (the engine scales them with the screen's DPI)
    int VisibleRows = 14;
    float Left = 60;
    float Top = 100;
    float Pad = 26;
    float RowH = 34;
    float BodySize = 16;
    float TitleSize = 30;
    float PathTop = 12;
    float TitleTop = 26;
    float RuleTop = 80;
    float ListTop = 98;
    const float MinWidth = 520;
    const float MaxWidth = 900;
    const float MinValueX = 344; // where the values start in the narrowest panel

    // set by Layout from the texts: translations run longer than the English ones
    float Width = 520;
    float ValueX = 344; // from the panel's left edge

    void LoadFonts()
    {
        if (BodyFont == nullptr)
            BodyFont = FAssetPreload::BlockingLoad(TSoftObjectPtr<UFont>(n"/Game/UI/Fonts/NotoSerif-Regular_Font.NotoSerif-Regular_Font"));
        if (TitleFont == nullptr)
            TitleFont = FAssetPreload::BlockingLoad(TSoftObjectPtr<UFont>(n"/Game/UI/Fonts/Boucherie-Block_Font.Boucherie-Block_Font"));
    }

    // a widget cannot measure text while painting, so widths are estimated from the length; this
    // share of the font size per character fits the game's serif font with a little to spare
    float TextWidth(FString S, float Size) const
    {
        return S.Len() * Size * 0.56;
    }

    // the value column starts after the longest label that has a value next to it, and the panel
    // is as wide as its longest line needs
    void Layout()
    {
        float labels = 0;
        float values = 0;
        float lines = 0;
        for (int i = 0; i < Labels.Num(); i++)
        {
            float label = TextWidth(Labels[i], BodySize);
            lines = Math::Max(lines, Pad + label);
            if (Values[i] != "" || IsPage[i])
                labels = Math::Max(labels, label);
            values = Math::Max(values, TextWidth(Values[i], BodySize));
        }
        ValueX = Math::Max(MinValueX, Pad + labels + 24);
        float width = Math::Max(MinWidth, ValueX + Math::Max(values, 20) + Pad);
        width = Math::Max(width, lines + Pad);
        // small text runs wider for its size, Cyrillic most of all
        width = Math::Max(width, 2 * Pad + TextWidth(Hint, 12) * 1.2);
        width = Math::Max(width, 2 * Pad + TextWidth(Status, 13) * 1.2);
        width = Math::Max(width, 2 * Pad + TextWidth(Title, TitleSize * 0.9) + 90);
        Width = Math::Min(width, MaxWidth);
        ValueX = Math::Min(ValueX, Width - Pad - Math::Max(values, 20));
    }

    void Repaint()
    {
        InvalidateLayoutAndVolatility();
    }

    // a filled rectangle: one thick line through its middle. The thickness is in screen pixels, not
    // in slate units like the positions, so it is scaled by the viewport's DPI scale.
    void Fill(FPaintContext& Context, float L, float T, float W, float H, FLinearColor Color) const
    {
        float scale = WidgetLayout::GetViewportScale();
        Widget::DrawLine(Context, FVector2D(L, T + H * 0.5), FVector2D(L + W, T + H * 0.5), Color, false, H * Math::Max(scale, 1.0));
    }

    void Text(FPaintContext& Context, FString S, float L, float T, UFont Font, float Size, FLinearColor Color) const
    {
        Widget::DrawTextFormatted(Context, FText::FromString(S), FVector2D(L, T), Font, Size, NAME_None, Color);
    }

    UFUNCTION(BlueprintOverride)
    void OnPaint(FPaintContext& Context) const
    {
        const FLinearColor backdrop = CM::Srgb(10, 10, 10, 0.92);
        const FLinearColor titleColor = CM::Srgb(243, 214, 203);
        const FLinearColor textColor = CM::Srgb(244, 226, 217);
        const FLinearColor valueColor = CM::Srgb(205, 160, 133);
        const FLinearColor muted = CM::Srgb(135, 134, 134);
        const FLinearColor hairline = CM::Srgb(87, 87, 87);
        const FLinearColor plate = CM::Srgb(250, 223, 207);
        const FLinearColor plateText = CM::Srgb(14, 12, 11);

        const int shown = Math::Min(VisibleRows, Labels.Num());
        const float listBottom = Top + ListTop + Math::Max(shown, 1) * RowH;
        const float footTop = listBottom + 12;
        const float height = footTop + 52 - Top;

        Fill(Context, Left, Top, Width, height, backdrop);

        Text(Context, Path, Left + Pad, Top + PathTop, BodyFont, 12, muted);
        Text(Context, Title, Left + Pad, Top + TitleTop, TitleFont, TitleSize, titleColor);
        // where the selection is in a list longer than the panel
        if (Labels.Num() > VisibleRows)
        {
            FString counter = "" + (Selected + 1) + " / " + Labels.Num();
            Text(Context, counter, Left + Width - Pad - TextWidth(counter, 13), Top + TitleTop + 14, BodyFont, 13, muted);
        }
        Fill(Context, Left + Pad, Top + RuleTop, Width - 2 * Pad, 1, hairline);

        for (int row = 0; row < shown; row++)
        {
            const int i = First + row;
            if (i >= Labels.Num())
                break;
            const float y = Top + ListTop + row * RowH;
            FLinearColor labelColor = textColor;
            FLinearColor rightColor = valueColor;
            if (i == Selected)
            {
                Fill(Context, Left + Pad - 10, y, Width - 2 * Pad + 20, RowH, plate);
                labelColor = plateText;
                rightColor = plateText;
            }
            Text(Context, Labels[i], Left + Pad, y + 5, BodyFont, BodySize, labelColor);
            FString right = Values[i];
            if (right == "" && IsPage[i])
                right = ">";
            if (right != "")
                Text(Context, right, Left + ValueX, y + 5, BodyFont, BodySize, rightColor);
        }

        // more rows above / below than fit
        if (First > 0)
            Text(Context, "...", Left + Width - Pad - 20, Top + ListTop - 22, BodyFont, BodySize, muted);
        if (First + shown < Labels.Num())
            Text(Context, "...", Left + Width - Pad - 20, listBottom - RowH + 5, BodyFont, BodySize, muted);

        Fill(Context, Left + Pad, listBottom + 4, Width - 2 * Pad, 1, hairline);
        Text(Context, Status, Left + Pad, footTop, BodyFont, 13, valueColor);
        Text(Context, Hint, Left + Pad, footTop + 22, BodyFont, 12, muted);
    }
}
