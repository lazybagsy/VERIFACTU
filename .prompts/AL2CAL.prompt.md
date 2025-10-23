---
mode: 'ask'
model: Claude Sonnet 4
description: 'Convert AL objects to CAL format for Navision 2018'
---
Convert the provided AL object(s) to CAL format compatible with Navision 2018. Create TXT files that can be imported directly into Navision 2018.

**Conversion Requirements:**

* **Object Structure:**
  - Use classic CAL syntax with OBJECT-PROPERTIES header
  - Include Date, Time, Modified, and Version List properties
  - Follow Navision 2018 object numbering scheme

* **Field Declarations:**
  - Convert AL field syntax to CAL format: `{ FieldNo ; ; FieldName ; DataType }`
  - Use CAL data types: Text20, Text50, Text100, Text250, Code2, Code10, Code20, Integer, Decimal, Date, DateTime, Boolean, Option
  - Convert DecimalPlaces notation: `DecimalPlaces=2:2`
  - Convert AutoIncrement to CAL format
  - Set Editable=False for non-editable fields (use False, not No)

* **Table Triggers:**
  - **OnInsert, OnModify, OnDelete, and OnRename triggers MUST be declared in the PROPERTIES section, NOT in the CODE section**
  - Table triggers are properties, not procedures
  - Format: Place trigger code directly in PROPERTIES after DataCaptionFields
  - Example:
    ```
    PROPERTIES
    {
      DataCaptionFields=Entry No.;
      OnModify=VAR
                 MyVar@1000000000 : Record 50138;
               BEGIN
                 // trigger code here
               END;
    }
    ```
  - Do NOT create OnInsert, OnModify, OnDelete, or OnRename as procedures in the CODE section
  - Leave CODE section with only BEGIN/END if no other procedures exist

* **Page Layouts:**
  - Respect the exact layout order from AL page
  - Convert page areas: ContentArea -> Container, repeater/group -> Group, fields -> Field
  - Use proper control IDs with sequential numbering
  - Map AL ApplicationArea to appropriate CAL properties

* **Actions:**
  - ActionList=ACTIONS must appear in the PROPERTIES section, not as a separate section
  - Convert action areas to ActionContainer with proper ActionContainerType
  - Preserve action properties: Promoted, PromotedCategory, Image, RunObject, RunPageLink
  - Convert trigger code from AL to CAL syntax
  - Use proper variable declarations with @ symbols for local variables

* **Code Conversion:**
  - Convert procedures to CAL LOCAL PROCEDURE format
  - Use @ symbol for local variable declarations: `Variable@1000000000 : Type`
  - Convert Rec. references to direct field references in pages
  - Convert AL method calls to CAL syntax (UPPERCASE for system functions)
  - Convert string concatenation and formatting functions
  - Handle Codeunit references with proper object numbers
  - Convert TempBlob usage to Record 99008535 for NAV 2018
  - **EventSubscriber declarations MUST include Object Type:** Use `[EventSubscriber(Codeunit,80,OnAfterSalesInvHeaderInsert)]` NOT `[EventSubscriber(80,OnAfterSalesInvHeaderInsert)]`
  - EventSubscriber format: `[EventSubscriber(ObjectType,ObjectID,EventName)]` where ObjectType is Codeunit, Table, Page, etc.
  - Example: `[EventSubscriber(Codeunit,80,OnAfterSalesInvHeaderInsert)]` for Sales-Post codeunit

* **Keys and Field Groups:**
  - Convert key definitions to CAL format
  - Include Clustered=Yes for primary keys
  - Add empty FIELDGROUPS section

* **XMLPort Structure:**
  - Use proper ELEMENTS section with GUIDs
  - GUIDs must use ONLY valid hexadecimal characters (0-9, A-F) - NO letters G-Z
  - GUID format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} where X is 0-9 or A-F
  - Convert table elements with SourceTable references
  - Convert field elements with proper DataType and SourceField
  - Set proper XMLPort properties: Direction, Format, Encoding

* **Special Handling:**
  - Convert FlowField CalcFormula to CAL syntax
  - Handle Option fields with OptionMembers and OptionCaption
  - Convert ExtendedDatatype=Masked to proper CAL property
  - Preserve all ToolTips and Captions in both languages
  - Maintain proper indentation and spacing
  - Convert CaptionML with both ENU and ESP captions with example format `CaptionML=[ENU=<NIF Empresa>;ESP=NIF Representante];`
  - Preserve ToolTipML in both languages with example format `ToolTipML=[ENU=<ToolTip ENU>;ESP=<ToolTip ESP>];`
  - Remove all accents and special characters from captions, tooltips, variable names and field names
  - Replace accented characters: á→a, é→e, í→i, ó→o, ú→u, ñ→n, Á→A, É→E, Í→I, Ó→O, Ú→U, Ñ→N
  - Replace special characters: º→o (e.g., Nº→No), ª→a
  - Example conversions: "Nº movimiento"→"No movimiento", "Fecha Expedición"→"Fecha Expedicion"

* **Output Format:**
  - Create separate .txt files for each object type
  - Name files as: NAV2018_[ObjectType][ObjectID]_[ObjectName].txt
  - Ensure files can be imported directly into Navision 2018
  - Include proper BEGIN/END blocks for CODE sections

**Example Data Type Mappings:**
- Text[20] -> Text20
- Text[50] -> Text50
- Text[100] -> Text100
- Text[250] -> Text250
- Code[2] -> Code2
- Code[20] -> Code20
- Integer -> Integer
- Decimal -> Decimal
- Date -> Date
- DateTime -> DateTime
- Boolean -> Boolean

**Important Notes:**
- Maintain exact field order and grouping from AL
- Preserve all captions in both ENU and ESP
- Keep all business logic and validation code
- Ensure proper OBJECT-PROPERTIES formatting
- Use consistent control ID numbering (1000000000+)
- Test that generated files can be imported without errors
- Use True/False for boolean properties, not Yes/No
- **Remember: Table triggers (OnInsert, OnModify, OnDelete, OnRename) go in PROPERTIES, not CODE**
