<#
    Version: 29

    OBS, ISE will not show you your objects properties in intellisense unless you run the script first.
    Normally running a WinForms script in ISE is a bad idea due to a bug with WinForms that causes ISE to freeze, with EasyGUI however you can safely run the script.
    When EasyGUI detects that you are running the script in ISE it will run everything except showing the GUI and then restart the script in a console where the GUI will also be shown, 
    this way you still get intellisense but the GUI won't make ISE freeze.
#>


function Initialize-EasyGUI{
    #This needs to be called before anything else in EasyGUI is called

    [Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')| Out-Null
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")| Out-Null
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName PresentationFramework
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
     
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '

        
    #Generates a variable $SYNC that can be accessed from all threads, store your objects there to access them from everywhere
    #Example: In main script $SYNC.TextBox = New-TextBox @{ Text = "Text" }
    #In thread $script:SYNC.TextBox.Text = "New Text"

    if(-not (Get-Variable SYNC -Scope Global -ErrorAction SilentlyContinue)){
        $global:SYNC = [Hashtable]::Synchronized(@{})
    }



    #Stores cursor types in a variable, this can then be used in the main script
    #Example $label = New-Label { Cursor = $CURSOR.Hand }
        
    $global:CURSOR = [Hashtable]::Synchronized(@{
        AppStarting = [System.Windows.Forms.Cursors]::AppStarting
        Arrow = [System.Windows.Forms.Cursors]::Arrow
        Cross = [System.Windows.Forms.Cursors]::Cross
        Default = [System.Windows.Forms.Cursors]::Default
        Hand = [System.Windows.Forms.Cursors]::Hand
        Help = [System.Windows.Forms.Cursors]::Help
        HSplit = [System.Windows.Forms.Cursors]::HSplit
        IBeam = [System.Windows.Forms.Cursors]::IBeam
        No = [System.Windows.Forms.Cursors]::No
        NoMove2D = [System.Windows.Forms.Cursors]::NoMove2D
        NoMoveHoriz = [System.Windows.Forms.Cursors]::NoMoveHoriz
        NoMoveVert = [System.Windows.Forms.Cursors]::NoMoveVert
        PanEast = [System.Windows.Forms.Cursors]::PanEast
        PanNE = [System.Windows.Forms.Cursors]::PanNE
        PanNorth = [System.Windows.Forms.Cursors]::PanNorth
        PanNW = [System.Windows.Forms.Cursors]::PanNW
        PanSE = [System.Windows.Forms.Cursors]::PanSE
        PanSouth = [System.Windows.Forms.Cursors]::PanSouth
        PanSW = [System.Windows.Forms.Cursors]::PanSW
        PanWest = [System.Windows.Forms.Cursors]::PanWest
        SizeAll = [System.Windows.Forms.Cursors]::SizeAll
        SizeNESW = [System.Windows.Forms.Cursors]::SizeNESW
        SizeNS = [System.Windows.Forms.Cursors]::SizeNS
        SizeNWSE = [System.Windows.Forms.Cursors]::SizeNWSE
        SizeWE = [System.Windows.Forms.Cursors]::SizeWE
        UpArrow = [System.Windows.Forms.Cursors]::UpArrow
        VSplit = [System.Windows.Forms.Cursors]::VSplit
        WaitCursor = [System.Windows.Forms.Cursors]::WaitCursor
    })



        
    #Stores FontStyle types in a variable, this can then be used in the main script
    #Example $label = New-Label { Font = New-Font -Font "Microsoft Sans Serif" -Size 12 -Style $FONTSTYLE.Bold }
        
    $global:FONTSTYLE = [Hashtable]::Synchronized(@{
        Bold = [System.Drawing.FontStyle]::Bold
        Italic = [System.Drawing.FontStyle]::Italic
        Regular = [System.Drawing.FontStyle]::Regular
        Strikeout = [System.Drawing.FontStyle]::Strikeout
        Underline = [System.Drawing.FontStyle]::Underline
    })



        
    #Stores DropdownStyle types in a variable, this can then be used in the main script
    #Example $comboBox = New-ComboBox { DropdownStyle = $DROPDOWNSTYLE.DropdownList }
        
    $global:DROPDOWNSTYLE = [Hashtable]::Synchronized(@{
        Dropdown = [System.Windows.Forms.ComboBoxStyle]::DropDown
        DropdownList = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        Simple = [System.Windows.Forms.ComboBoxStyle]::Simple
    })



}

function Hide-Console{
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)
}
    
function Show-Console{
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 5)
} 

function Stop-Console{
    [System.Windows.Forms.Application]::Exit()
    if($PSISE -EQ $NULL){
        exit 0
    }
}

function Show-Form{
    param([System.Windows.Forms.Form]$form, [switch]$run, [switch]$Async)
    if($PSISE -eq $NULL){
        if ($run){
            [void][System.Windows.Forms.Application]::Run($form)
        }else{
            $form.ShowDialog()
        }
    }else{
        Start-Process powershell -ArgumentList $MyInvocation.ScriptName
        Write-Warning "Due to a bug in ISE we will restart the script in a console session. If ISE displays a form it will freeze after a while and needs to be forced closed."
    }
}


function Enable-VisualStyles{
    [System.Windows.Forms.Application]::EnableVisualStyles()
}


#region ################################### MULTITHREADING (ish) ###################################
    #Store things in $SYNC (gets automatically created when calling Initialize-EasyGUI) to be able to access them from inside threads
    #Example: In main script $SYNC.textbox = New-TextBox @{ Text = "Text" }
    #In thread $script:SYNC.textbox.Text = "New Text"


function New-Thread{

    #Examples    
    # $myThread = { New-Thread { Get-Process } }        
    # $myThread = { New-Thread "C:\users\user\Powershell\myThread.ps1" }


    param(
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName="ScriptBlock")]
        [ScriptBlock]$ScriptBlock,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName="ps1Path")]
        [String]$ps1Path
    )
        
    if($PsCmdlet.ParameterSetName -eq "ps1Path"){ #Emulates function overloading, see http://codepyre.com/2012/08/ad-hoc-polymorphism-in-powershell/
        $ScriptBlock = [scriptblock]::Create($ps1Path)
    }


    $thread = [PowerShell]::Create().AddScript($ScriptBlock)
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("SYNC", $SYNC)
    $thread.Runspace = $runspace
    $thread.BeginInvoke()

}

#endregion
    
#region ################################### NEW-OBJECTS WinForms ###################################
    #Functions for creating WinForms objects
    #OBS, when updating these functions don´t do that by hand, they are to be generated with the script New-WinFormsFunctions.ps1
    

    function New-AccessibleObject{
        [OutputType([System.Windows.Forms.AccessibleObject])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.AccessibleObject -Property $Property
    }
    

    function New-AmbientProperties{
        [OutputType([System.Windows.Forms.AmbientProperties])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.AmbientProperties -Property $Property
    }
    

    function New-ApplicationContext{
        [OutputType([System.Windows.Forms.ApplicationContext])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ApplicationContext -Property $Property
    }
    

    function New-BaseCollection{
        [OutputType([System.Windows.Forms.BaseCollection])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.BaseCollection -Property $Property
    }
    

    function New-BindingContext{
        [OutputType([System.Windows.Forms.BindingContext])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.BindingContext -Property $Property
    }
    

    function New-BindingMemberInfo{
        [OutputType([System.Windows.Forms.BindingMemberInfo])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.BindingMemberInfo -Property $Property
    }
    

    function New-BindingNavigator{
        [OutputType([System.Windows.Forms.BindingNavigator])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.BindingNavigator -Property $Property
    }
    

    function New-Button{
        [OutputType([System.Windows.Forms.Button])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Button -Property $Property
    }
    

    function New-CheckBox{
        [OutputType([System.Windows.Forms.CheckBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.CheckBox -Property $Property
    }
    

    function New-CheckedListBox{
        [OutputType([System.Windows.Forms.CheckedListBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.CheckedListBox -Property $Property
    }
    

    function New-ColorDialog{
        [OutputType([System.Windows.Forms.ColorDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ColorDialog -Property $Property
    }
    

    function New-ColumnHeader{
        [OutputType([System.Windows.Forms.ColumnHeader])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ColumnHeader -Property $Property
    }
    

    function New-ColumnHeaderConverter{
        [OutputType([System.Windows.Forms.ColumnHeaderConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ColumnHeaderConverter -Property $Property
    }
    

    function New-ColumnStyle{
        [OutputType([System.Windows.Forms.ColumnStyle])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ColumnStyle -Property $Property
    }
    

    function New-ComboBox{
        [OutputType([System.Windows.Forms.ComboBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ComboBox -Property $Property
    }
    

    function New-ContainerControl{
        [OutputType([System.Windows.Forms.ContainerControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ContainerControl -Property $Property
    }
    

    function New-ContextMenu{
        [OutputType([System.Windows.Forms.ContextMenu])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ContextMenu -Property $Property
    }
    

    function New-ContextMenuStrip{
        [OutputType([System.Windows.Forms.ContextMenuStrip])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ContextMenuStrip -Property $Property
    }
    

    function New-Control{
        [OutputType([System.Windows.Forms.Control])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Control -Property $Property
    }
    

    function New-CreateParams{
        [OutputType([System.Windows.Forms.CreateParams])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.CreateParams -Property $Property
    }
    

    function New-CursorConverter{
        [OutputType([System.Windows.Forms.CursorConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.CursorConverter -Property $Property
    }
    

    function New-DataGrid{
        [OutputType([System.Windows.Forms.DataGrid])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGrid -Property $Property
    }
    

    function New-DataGridBoolColumn{
        [OutputType([System.Windows.Forms.DataGridBoolColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridBoolColumn -Property $Property
    }
    

    function New-DataGridCell{
        [OutputType([System.Windows.Forms.DataGridCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridCell -Property $Property
    }
    

    function New-DataGridPreferredColumnWidthTypeConverter{
        [OutputType([System.Windows.Forms.DataGridPreferredColumnWidthTypeConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridPreferredColumnWidthTypeConverter -Property $Property
    }
    

    function New-DataGridTableStyle{
        [OutputType([System.Windows.Forms.DataGridTableStyle])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridTableStyle -Property $Property
    }
    

    function New-DataGridTextBox{
        [OutputType([System.Windows.Forms.DataGridTextBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridTextBox -Property $Property
    }
    

    function New-DataGridTextBoxColumn{
        [OutputType([System.Windows.Forms.DataGridTextBoxColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridTextBoxColumn -Property $Property
    }
    

    function New-DataGridView{
        [OutputType([System.Windows.Forms.DataGridView])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridView -Property $Property
    }
    

    function New-DataGridViewAdvancedBorderStyle{
        [OutputType([System.Windows.Forms.DataGridViewAdvancedBorderStyle])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewAdvancedBorderStyle -Property $Property
    }
    

    function New-DataGridViewButtonCell{
        [OutputType([System.Windows.Forms.DataGridViewButtonCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewButtonCell -Property $Property
    }
    

    function New-DataGridViewButtonColumn{
        [OutputType([System.Windows.Forms.DataGridViewButtonColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewButtonColumn -Property $Property
    }
    

    function New-DataGridViewCellStyle{
        [OutputType([System.Windows.Forms.DataGridViewCellStyle])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewCellStyle -Property $Property
    }
    

    function New-DataGridViewCellStyleConverter{
        [OutputType([System.Windows.Forms.DataGridViewCellStyleConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewCellStyleConverter -Property $Property
    }
    

    function New-DataGridViewCheckBoxCell{
        [OutputType([System.Windows.Forms.DataGridViewCheckBoxCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewCheckBoxCell -Property $Property
    }
    

    function New-DataGridViewCheckBoxColumn{
        [OutputType([System.Windows.Forms.DataGridViewCheckBoxColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewCheckBoxColumn -Property $Property
    }
    

    function New-DataGridViewColumn{
        [OutputType([System.Windows.Forms.DataGridViewColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewColumn -Property $Property
    }
    

    function New-DataGridViewColumnDesignTimeVisibleAttribute{
        [OutputType([System.Windows.Forms.DataGridViewColumnDesignTimeVisibleAttribute])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewColumnDesignTimeVisibleAttribute -Property $Property
    }
    

    function New-DataGridViewColumnHeaderCell{
        [OutputType([System.Windows.Forms.DataGridViewColumnHeaderCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewColumnHeaderCell -Property $Property
    }
    

    function New-DataGridViewComboBoxCell{
        [OutputType([System.Windows.Forms.DataGridViewComboBoxCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewComboBoxCell -Property $Property
    }
    

    function New-DataGridViewComboBoxColumn{
        [OutputType([System.Windows.Forms.DataGridViewComboBoxColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewComboBoxColumn -Property $Property
    }
    

    function New-DataGridViewComboBoxEditingControl{
        [OutputType([System.Windows.Forms.DataGridViewComboBoxEditingControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewComboBoxEditingControl -Property $Property
    }
    

    function New-DataGridViewElement{
        [OutputType([System.Windows.Forms.DataGridViewElement])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewElement -Property $Property
    }
    

    function New-DataGridViewHeaderCell{
        [OutputType([System.Windows.Forms.DataGridViewHeaderCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewHeaderCell -Property $Property
    }
    

    function New-DataGridViewImageCell{
        [OutputType([System.Windows.Forms.DataGridViewImageCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewImageCell -Property $Property
    }
    

    function New-DataGridViewImageColumn{
        [OutputType([System.Windows.Forms.DataGridViewImageColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewImageColumn -Property $Property
    }
    

    function New-DataGridViewLinkCell{
        [OutputType([System.Windows.Forms.DataGridViewLinkCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewLinkCell -Property $Property
    }
    

    function New-DataGridViewLinkColumn{
        [OutputType([System.Windows.Forms.DataGridViewLinkColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewLinkColumn -Property $Property
    }
    

    function New-DataGridViewRow{
        [OutputType([System.Windows.Forms.DataGridViewRow])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewRow -Property $Property
    }
    

    function New-DataGridViewRowHeaderCell{
        [OutputType([System.Windows.Forms.DataGridViewRowHeaderCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewRowHeaderCell -Property $Property
    }
    

    function New-DataGridViewTextBoxCell{
        [OutputType([System.Windows.Forms.DataGridViewTextBoxCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewTextBoxCell -Property $Property
    }
    

    function New-DataGridViewTextBoxColumn{
        [OutputType([System.Windows.Forms.DataGridViewTextBoxColumn])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property $Property
    }
    

    function New-DataGridViewTextBoxEditingControl{
        [OutputType([System.Windows.Forms.DataGridViewTextBoxEditingControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewTextBoxEditingControl -Property $Property
    }
    

    function New-DataGridViewTopLeftHeaderCell{
        [OutputType([System.Windows.Forms.DataGridViewTopLeftHeaderCell])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataGridViewTopLeftHeaderCell -Property $Property
    }
    

    function New-DataObject{
        [OutputType([System.Windows.Forms.DataObject])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DataObject -Property $Property
    }
    

    function New-DateTimePicker{
        [OutputType([System.Windows.Forms.DateTimePicker])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DateTimePicker -Property $Property
    }
    

    function New-DockingAttribute{
        [OutputType([System.Windows.Forms.DockingAttribute])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DockingAttribute -Property $Property
    }
    

    function New-DomainUpDown{
        [OutputType([System.Windows.Forms.DomainUpDown])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.DomainUpDown -Property $Property
    }
    

    function New-ErrorProvider{
        [OutputType([System.Windows.Forms.ErrorProvider])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ErrorProvider -Property $Property
    }
    

    function New-FlowLayoutPanel{
        [OutputType([System.Windows.Forms.FlowLayoutPanel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.FlowLayoutPanel -Property $Property
    }
    

    function New-FolderBrowserDialog{
        [OutputType([System.Windows.Forms.FolderBrowserDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.FolderBrowserDialog -Property $Property
    }
    

    function New-FontDialog{
        [OutputType([System.Windows.Forms.FontDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.FontDialog -Property $Property
    }
    

    function New-Form{
        [OutputType([System.Windows.Forms.Form])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Form -Property $Property
    }
    

    function New-FormCollection{
        [OutputType([System.Windows.Forms.FormCollection])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.FormCollection -Property $Property
    }
    

    function New-GroupBox{
        [OutputType([System.Windows.Forms.GroupBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.GroupBox -Property $Property
    }
    

    function New-HelpProvider{
        [OutputType([System.Windows.Forms.HelpProvider])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.HelpProvider -Property $Property
    }
    

    function New-HScrollBar{
        [OutputType([System.Windows.Forms.HScrollBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.HScrollBar -Property $Property
    }
    

    function New-ImageIndexConverter{
        [OutputType([System.Windows.Forms.ImageIndexConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ImageIndexConverter -Property $Property
    }
    

    function New-ImageKeyConverter{
        [OutputType([System.Windows.Forms.ImageKeyConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ImageKeyConverter -Property $Property
    }
    

    function New-ImageList{
        [OutputType([System.Windows.Forms.ImageList])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ImageList -Property $Property
    }
    

    function New-ImeModeConversion{
        [OutputType([System.Windows.Forms.ImeModeConversion])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ImeModeConversion -Property $Property
    }
    

    function New-KeysConverter{
        [OutputType([System.Windows.Forms.KeysConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.KeysConverter -Property $Property
    }
    

    function New-Label{
        [OutputType([System.Windows.Forms.Label])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Label -Property $Property
    }
    

    function New-LinkArea{
        [OutputType([System.Windows.Forms.LinkArea])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.LinkArea -Property $Property
    }
    

    function New-LinkConverter{
        [OutputType([System.Windows.Forms.LinkConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.LinkConverter -Property $Property
    }
    

    function New-LinkLabel{
        [OutputType([System.Windows.Forms.LinkLabel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.LinkLabel -Property $Property
    }
    

    function New-ListBindingConverter{
        [OutputType([System.Windows.Forms.ListBindingConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListBindingConverter -Property $Property
    }
    

    function New-ListBox{
        [OutputType([System.Windows.Forms.ListBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListBox -Property $Property
    }
    

    function New-ListView{
        [OutputType([System.Windows.Forms.ListView])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListView -Property $Property
    }
    

    function New-ListViewGroup{
        [OutputType([System.Windows.Forms.ListViewGroup])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListViewGroup -Property $Property
    }
    

    function New-ListViewItem{
        [OutputType([System.Windows.Forms.ListViewItem])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListViewItem -Property $Property
    }
    

    function New-ListViewItemConverter{
        [OutputType([System.Windows.Forms.ListViewItemConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ListViewItemConverter -Property $Property
    }
    

    function New-MainMenu{
        [OutputType([System.Windows.Forms.MainMenu])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MainMenu -Property $Property
    }
    

    function New-MaskedTextBox{
        [OutputType([System.Windows.Forms.MaskedTextBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MaskedTextBox -Property $Property
    }
    

    function New-MdiClient{
        [OutputType([System.Windows.Forms.MdiClient])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MdiClient -Property $Property
    }
    

    function New-MenuItem{
        [OutputType([System.Windows.Forms.MenuItem])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MenuItem -Property $Property
    }
    

    function New-MenuStrip{
        [OutputType([System.Windows.Forms.MenuStrip])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MenuStrip -Property $Property
    }
    

    function New-Message{
        [OutputType([System.Windows.Forms.Message])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Message -Property $Property
    }
    

    function New-MonthCalendar{
        [OutputType([System.Windows.Forms.MonthCalendar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.MonthCalendar -Property $Property
    }
    

    function New-NativeWindow{
        [OutputType([System.Windows.Forms.NativeWindow])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.NativeWindow -Property $Property
    }
    

    function New-NotifyIcon{
        [OutputType([System.Windows.Forms.NotifyIcon])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.NotifyIcon -Property $Property
    }
    

    function New-NumericUpDown{
        [OutputType([System.Windows.Forms.NumericUpDown])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.NumericUpDown -Property $Property
    }
    

    function New-NumericUpDownAccelerationCollection{
        [OutputType([System.Windows.Forms.NumericUpDownAccelerationCollection])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.NumericUpDownAccelerationCollection -Property $Property
    }
    

    function New-OpacityConverter{
        [OutputType([System.Windows.Forms.OpacityConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.OpacityConverter -Property $Property
    }
    

    function New-OpenFileDialog{
        [OutputType([System.Windows.Forms.OpenFileDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.OpenFileDialog -Property $Property
    }
    

    function New-Padding{
        [OutputType([System.Windows.Forms.Padding])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Padding -Property $Property
    }
    

    function New-PaddingConverter{
        [OutputType([System.Windows.Forms.PaddingConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PaddingConverter -Property $Property
    }
    

    function New-PageSetupDialog{
        [OutputType([System.Windows.Forms.PageSetupDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PageSetupDialog -Property $Property
    }
    

    function New-Panel{
        [OutputType([System.Windows.Forms.Panel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Panel -Property $Property
    }
    

    function New-PictureBox{
        [OutputType([System.Windows.Forms.PictureBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PictureBox -Property $Property
    }
    

    function New-PrintDialog{
        [OutputType([System.Windows.Forms.PrintDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PrintDialog -Property $Property
    }
    

    function New-PrintPreviewControl{
        [OutputType([System.Windows.Forms.PrintPreviewControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PrintPreviewControl -Property $Property
    }
    

    function New-PrintPreviewDialog{
        [OutputType([System.Windows.Forms.PrintPreviewDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PrintPreviewDialog -Property $Property
    }
    

    function New-ProfessionalColorTable{
        [OutputType([System.Windows.Forms.ProfessionalColorTable])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ProfessionalColorTable -Property $Property
    }
    

    function New-ProgressBar{
        [OutputType([System.Windows.Forms.ProgressBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ProgressBar -Property $Property
    }
    

    function New-PropertyGrid{
        [OutputType([System.Windows.Forms.PropertyGrid])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PropertyGrid -Property $Property
    }
    

    function New-PropertyManager{
        [OutputType([System.Windows.Forms.PropertyManager])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.PropertyManager -Property $Property
    }
    

    function New-QueryAccessibilityHelpEventArgs{
        [OutputType([System.Windows.Forms.QueryAccessibilityHelpEventArgs])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.QueryAccessibilityHelpEventArgs -Property $Property
    }
    

    function New-QuestionEventArgs{
        [OutputType([System.Windows.Forms.QuestionEventArgs])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.QuestionEventArgs -Property $Property
    }
    

    function New-RadioButton{
        [OutputType([System.Windows.Forms.RadioButton])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.RadioButton -Property $Property
    }
    

    function New-RichTextBox{
        [OutputType([System.Windows.Forms.RichTextBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.RichTextBox -Property $Property
    }
    

    function New-RowStyle{
        [OutputType([System.Windows.Forms.RowStyle])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.RowStyle -Property $Property
    }
    

    function New-SaveFileDialog{
        [OutputType([System.Windows.Forms.SaveFileDialog])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.SaveFileDialog -Property $Property
    }
    

    function New-ScrollableControl{
        [OutputType([System.Windows.Forms.ScrollableControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ScrollableControl -Property $Property
    }
    

    function New-SelectionRange{
        [OutputType([System.Windows.Forms.SelectionRange])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.SelectionRange -Property $Property
    }
    

    function New-SelectionRangeConverter{
        [OutputType([System.Windows.Forms.SelectionRangeConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.SelectionRangeConverter -Property $Property
    }
    

    function New-SplitContainer{
        [OutputType([System.Windows.Forms.SplitContainer])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.SplitContainer -Property $Property
    }
    

    function New-Splitter{
        [OutputType([System.Windows.Forms.Splitter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Splitter -Property $Property
    }
    

    function New-StatusBar{
        [OutputType([System.Windows.Forms.StatusBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.StatusBar -Property $Property
    }
    

    function New-StatusBarPanel{
        [OutputType([System.Windows.Forms.StatusBarPanel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.StatusBarPanel -Property $Property
    }
    

    function New-StatusStrip{
        [OutputType([System.Windows.Forms.StatusStrip])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.StatusStrip -Property $Property
    }
    

    function New-TabControl{
        [OutputType([System.Windows.Forms.TabControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TabControl -Property $Property
    }
    

    function New-TableLayoutPanel{
        [OutputType([System.Windows.Forms.TableLayoutPanel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TableLayoutPanel -Property $Property
    }
    

    function New-TableLayoutPanelCellPosition{
        [OutputType([System.Windows.Forms.TableLayoutPanelCellPosition])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TableLayoutPanelCellPosition -Property $Property
    }
    

    function New-TabPage{
        [OutputType([System.Windows.Forms.TabPage])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TabPage -Property $Property
    }
    

    function New-TextBox{
        [OutputType([System.Windows.Forms.TextBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TextBox -Property $Property
    }
    

    function New-Timer{
        [OutputType([System.Windows.Forms.Timer])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.Timer -Property $Property
    }
    

    function New-ToolBar{
        [OutputType([System.Windows.Forms.ToolBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolBar -Property $Property
    }
    

    function New-ToolBarButton{
        [OutputType([System.Windows.Forms.ToolBarButton])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolBarButton -Property $Property
    }
    

    function New-ToolStrip{
        [OutputType([System.Windows.Forms.ToolStrip])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStrip -Property $Property
    }
    

    function New-ToolStripButton{
        [OutputType([System.Windows.Forms.ToolStripButton])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripButton -Property $Property
    }
    

    function New-ToolStripComboBox{
        [OutputType([System.Windows.Forms.ToolStripComboBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripComboBox -Property $Property
    }
    

    function New-ToolStripContainer{
        [OutputType([System.Windows.Forms.ToolStripContainer])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripContainer -Property $Property
    }
    

    function New-ToolStripContentPanel{
        [OutputType([System.Windows.Forms.ToolStripContentPanel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripContentPanel -Property $Property
    }
    

    function New-ToolStripDropDown{
        [OutputType([System.Windows.Forms.ToolStripDropDown])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripDropDown -Property $Property
    }
    

    function New-ToolStripDropDownButton{
        [OutputType([System.Windows.Forms.ToolStripDropDownButton])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripDropDownButton -Property $Property
    }
    

    function New-ToolStripDropDownMenu{
        [OutputType([System.Windows.Forms.ToolStripDropDownMenu])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripDropDownMenu -Property $Property
    }
    

    function New-ToolStripLabel{
        [OutputType([System.Windows.Forms.ToolStripLabel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripLabel -Property $Property
    }
    

    function New-ToolStripMenuItem{
        [OutputType([System.Windows.Forms.ToolStripMenuItem])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripMenuItem -Property $Property
    }
    

    function New-ToolStripPanel{
        [OutputType([System.Windows.Forms.ToolStripPanel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripPanel -Property $Property
    }
    

    function New-ToolStripProfessionalRenderer{
        [OutputType([System.Windows.Forms.ToolStripProfessionalRenderer])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripProfessionalRenderer -Property $Property
    }
    

    function New-ToolStripProgressBar{
        [OutputType([System.Windows.Forms.ToolStripProgressBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripProgressBar -Property $Property
    }
    

    function New-ToolStripSeparator{
        [OutputType([System.Windows.Forms.ToolStripSeparator])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripSeparator -Property $Property
    }
    

    function New-ToolStripSplitButton{
        [OutputType([System.Windows.Forms.ToolStripSplitButton])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripSplitButton -Property $Property
    }
    

    function New-ToolStripStatusLabel{
        [OutputType([System.Windows.Forms.ToolStripStatusLabel])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripStatusLabel -Property $Property
    }
    

    function New-ToolStripSystemRenderer{
        [OutputType([System.Windows.Forms.ToolStripSystemRenderer])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripSystemRenderer -Property $Property
    }
    

    function New-ToolStripTextBox{
        [OutputType([System.Windows.Forms.ToolStripTextBox])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolStripTextBox -Property $Property
    }
    

    function New-ToolTip{
        [OutputType([System.Windows.Forms.ToolTip])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.ToolTip -Property $Property
    }
    

    function New-TrackBar{
        [OutputType([System.Windows.Forms.TrackBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TrackBar -Property $Property
    }
    

    function New-TreeNode{
        [OutputType([System.Windows.Forms.TreeNode])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TreeNode -Property $Property
    }
    

    function New-TreeNodeConverter{
        [OutputType([System.Windows.Forms.TreeNodeConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TreeNodeConverter -Property $Property
    }
    

    function New-TreeView{
        [OutputType([System.Windows.Forms.TreeView])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TreeView -Property $Property
    }
    

    function New-TreeViewImageIndexConverter{
        [OutputType([System.Windows.Forms.TreeViewImageIndexConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TreeViewImageIndexConverter -Property $Property
    }
    

    function New-TreeViewImageKeyConverter{
        [OutputType([System.Windows.Forms.TreeViewImageKeyConverter])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.TreeViewImageKeyConverter -Property $Property
    }
    

    function New-UserControl{
        [OutputType([System.Windows.Forms.UserControl])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.UserControl -Property $Property
    }
    

    function New-VScrollBar{
        [OutputType([System.Windows.Forms.VScrollBar])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.VScrollBar -Property $Property
    }
    

    function New-WebBrowser{
        [OutputType([System.Windows.Forms.WebBrowser])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.WebBrowser -Property $Property
    }
    

    function New-WindowsFormsSection{
        [OutputType([System.Windows.Forms.WindowsFormsSection])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.WindowsFormsSection -Property $Property
    }
    

    function New-WindowsFormsSynchronizationContext{
        [OutputType([System.Windows.Forms.WindowsFormsSynchronizationContext])]
        param([HashTable]$Property)
        New-Object System.Windows.Forms.WindowsFormsSynchronizationContext -Property $Property
    }
    
#endregion
   
#region ################################### NEW-OBJECTS Others ###################################
    #Here you can find GUI objects that are not from WinForms but still may be usefull in a WinForms GUI
    
    	
function New-DrawingSize{
    #TODO, add function overloading so you can use for example New-DrawingSize -Height 10
    param([HashTable]$Property)
    return New-Object System.Drawing.Size -Property $Property
}

function New-Font{
    param([String]$Font, [int]$Size, [System.Drawing.FontStyle]$style)
    return New-ObjectÂ System.Drawing.Font($Font, $Size, $Style)
}

function New-MessageBox{
    param([String]$Title = "", [String]$Text, [String]$Type = "ok")
    [System.Windows.MessageBox]::Show($Text, $Title, $Type)
}

function New-Point{
    param([HashTable]$Property)
    return New-Object System.Drawing.Point -Property $Property
}

function New-Popup{
    #This is using VBScript popup, more info about it can be found here https://ss64.com/vb/popup.html
    param(
        [String]$Title = "", 
        [String]$Text, 
        $Type = 0, 
        [Switch]$Type:OkOnly,
        [Switch]$Type:OkCancel,
        [Switch]$Type:AbortRetryIgnore,
        [Switch]$Type:YesNoCancel,
        [Switch]$Type:YesNo,
        [Switch]$Type:RetryCancel,
        $Icon = 0, 
        [Switch]$Icon:Critical,
        [Switch]$Icon:Question,
        [Switch]$Icon:Exclamation,
        [Switch]$Icon:Information,
        [Switch]$ReturnText
    )
    
    switch($Type){
        "OKOnly" { $Type = 0 }
        "OkCancel" { $Type = 1 }
        "AbortRetryIgnore" { $Type = 2 }
        "YesNoCancel" { $Type = 3 }
        "YesNo" { $Type = 4 }
        "RetryCancel" { $Type = 5 }
        default { if($Type -notmatch '^[0-9]+$'){ $Type = 0 } }
    }

    switch($Icon){
        "Critical" { $Icon = 16 }
        "Question" { $Icon = 32 }
        "Exclamation" { $Icon = 48 }
        "Information" { $Icon = 64 }
        default { if($Icon -notmatch '^[0-9]+$'){ $Icon = 0 } }
    }

    $stringReturns = @{
        "1" = "OK"
        "2" = "Cancel"
        "3" = "Abort"
        "4" = "Retry"
        "5" = "Ignore"
        "6" = "Yes"
        "7" = "No"
    }

    $return = (New-Object -ComObject WScript.Shell).Popup($Text, 0, $Title, $($Type+$Icon))

    #If $Type+$Icon is a number that VBS Popup don't support no popup is shown, if so show an OkOnly popup without any icons
    if($return -eq $NULL){
        $return = (New-Object -ComObject WScript.Shell).Popup($Text, 0, $Title, 0)
    }

    if($ReturnText){
        $return = $stringReturns["$return"]
    }

    return $return
}

#endregion

#region ################################### CUSTOM OBJECTS ###################################
    #This is where you find premade custom objects

function New-ArrayItemSelector{
    param([String[]]$StringArray, [String]$Title = "Doubleclick to select option", [int]$Width = 300, [int]$Height = 300)
    $global:arrayListSelector = $null
    $ArrayItemSelectorForm = New-Form @{
        Size = "$Width, $Height"
        Text = $title  
        FormBorderStyle = 'FixedDialog'
        MaximizeBox = $FALSE
    }
    $scriptblock = {
        $rowIndex = $datagrid.CurrentRow.Index
        $columnIndex = $datagrid.CurrentCell.ColumnIndex
        $global:arrayListSelector = $datagrid.Rows[$rowIndex].Cells[$columnIndex].value
        $ArrayItemSelectorForm.close()
    }
    $datagrid = New-DataGridView @{
        Location = "0, 0"
        Size = "$Width, $Height"
        AllowUserToAddRows = $FALSE
        ColumnCount = 1
        ReadOnly = $TRUE
        Add_CellMouseDoubleClick = $scriptblock
        Add_Keydown = { 
            if($_.KeyCode -eq "Enter"){ 
                & $scriptblock
            }
        }
    }
    $datagrid.Columns[0].Width = $Width
    $StringArray|foreach-object{
        $datagrid.Rows.Add($_)|Out-Null
    }
    $ArrayItemSelectorForm.Controls.AddRange(@(
        $datagrid
    ))
    $ArrayItemSelectorForm.showdialog()|Out-Null
    return [string]$($global:arrayListSelector)
}

function New-InputBox{
    param(
        [String]$Title = "", 
        [String]$Text = "", 
        [String]$ButtonText = "Submit", 
        [int]$Width = 380, 
        [int]$Height = 170,
        [switch]$vbsInputBox
    )
    if($vbsInputBox){
        #VB inputbox, info about VBs inputbox can be found at https://msdn.microsoft.com/en-us/library/microsoft.visualbasic.interaction.inputbox(v=vs.110).aspx
        [Microsoft.VisualBasic.Interaction]::InputBox($Text, $Title)
    }else{
        #Custom inputbox (default)
        if($Width -lt 200) { $Width = 200 }
        if($Height -lt 120) { $Height = 120 }
        
        $global:inputBoxText = ""
        $inputBoxForm = New-Form @{
            Size = "$Width, $Height"
            Text = $Title  
            FormBorderStyle = 'FixedDialog'
            MaximizeBox = $FALSE
        }
        $inputBoxLabel = New-Label @{
            AutoSize = $True
            Location = "15, 15"
            Text = $Text
            MaximumSize = "$($Width - 30), $($Height - 50)"
        }
        $inputBoxTextbox = New-TextBox @{
            Size = "$($Width-130), 25"
            Location = "15, $($Height-70)"
            Add_Keydown = { 
                if($_.KeyCode -eq "Enter"){ 
                    $inputBoxButton.PerformClick()
                }
            }
        }
        $inputBoxButton = New-Button @{
            Size = "75, 25"
            Location = "$($Width-110), $($Height-70)"
            Text = $ButtonText
            Add_Click = {
                $global:inputBoxText = $inputBoxTextbox.Text.Trim()
                $inputBoxForm.close()
            }
        }
        $inputBoxForm.Controls.AddRange(@(
            $inputBoxLabel, $inputBoxTextbox, $inputBoxButton
        ))
        $inputBoxForm.showdialog()|Out-Null
        return [String]$global:inputBoxText
    }
}

#endregion

#region ########################################## MISC ##########################################
   #For miscellaneous helper functions that don't fit in any other category

function Get-Icon{
    param([String]$File, [int]$IconNumber = 0, [boolean]$LargeIcon = $TRUE)
    switch($File){
        "Explorer" { return Get-Icon "C:\Windows\explorer.exe" }
        "Internet" { return Get-Icon "C:\Program Files\Internet Explorer\iexplore.exe" }
        "Notepad" { return Get-Icon "C:\Windows\System32\Notepad.exe" }
        "Powershell" { return Get-Icon "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe" }
        default { return [System.IconExtractor]::Extract($File, $IconNumber, $LargeIcon) }
    }
}

#endregion

#region ######################################### ALIASES #########################################
   #This is for setting aliases, manly to keep backward compatibility

Set-Alias -Name New-Alert -Value New-MessageBox
Set-Alias -Name Use-EasyGUI -Value Initialize-EasyGUI

#endregion

#region ################################### ICON EXTRACTOR CLASS ###################################
    #This is used to export icons from dll or exe files
    #This is only meant to be used internally, instead use Get-Icon

$code = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace System{
    public class IconExtractor{
        public static Icon Extract(string file, int number, bool largeIcon){
            IntPtr large;
            IntPtr small;
            ExtractIconEx(file, number, out large, out small, 1);
            try{
                return Icon.FromHandle(largeIcon ? large : small);
            }catch{
                return null;
            }

        }
        [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
    }
}
"@
Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

#endregion