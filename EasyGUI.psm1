<#
    Version: 23

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
    
function Use-EasyGUI{
    Initialize-EasyGUI
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
        [Environment]::Exit(1)
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


################################### MULTITHREADING (ish) ###################################
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
    
################################### NEW-OBJECTS WinForms ###################################
    #This is where all the WinForms objects can be found
    #OBS, not every object has been added yet since I add them as needed


function New-Button{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.Button -Property $Property
}
	
function New-Checkbox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.Checkbox -Property $Property
}
	
function New-ComboBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ComboBox -Property $Property
}
	
function New-DataGridView{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.DataGridView -Property $Property
}
	
function New-FlowLayoutPanel{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.FlowLayoutPanel -Property $Property
}
	
function New-Form($Property){
    return New-Object System.Windows.Forms.Form -Property $Property
}
	
function New-GroupBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.GroupBox -Property $Property
}
    
function New-Label{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.Label -Property $Property
}
    
function New-ListBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ListBox -Property $Property
}
    
function New-MenuStrip{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.MenuStrip -Property $Property
}

function New-OpenFileDialog{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.OpenFileDialog -Property $Property
}

function New-Padding{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.Padding -Property $Property
}

function New-Panel{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.Panel -Property $Property
}

function New-PictureBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.PictureBox -Property $Property
}
    
function New-ProgressBar{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ProgressBar -Property $Property
}
    
function New-RadioButton{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.RadioButton -Property $Property
}
    
function New-RichTextBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.RichTextBox -Property $Property
}
    
function New-SaveFileDialog{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.SaveFileDialog -Property $Property
}
    
function New-StatusBar{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.StatusBar -Property $Property
}

function New-TabControl{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.TabControl -Property $Property
}	

function New-TabPage{
    param([Hashtable]$Property)
    return New-Object System.Windows.Forms.TabPage -Property $Property
}

function New-TextBox{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.TextBox -Property $Property
}
	
function New-ToolStripMenuItem{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ToolStripMenuItem -Property $Property
}
	
function New-ToolStripSeparator{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ToolStripSeparator -Property $Property
}

function New-ToolTip{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.ToolTip -Property $Property
}
	
function New-WebBrowser{
    param([HashTable]$Property)
    return New-Object System.Windows.Forms.WebBrowser -Property $Property
}
    



################################### NEW-OBJECTS Others ###################################
    #Here you can find GUI objects that are not from WinForms but still may be usefull in a WinForms GUI
    
    	
function New-DrawingSize{
    #TODO, add function overloading so you can use for example New-DrawingSize -Height 10
    param([HashTable]$Property)
    return New-Object System.Drawing.Size -Property $Property
}

function New-Font{
    param([String]$Font, [int]$Size, [System.Drawing.FontStyle]$style)
    return New-Object System.Drawing.Font($Font, $Size, $Style)
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
        "OkOnly" { $Type = 0 }
        "OkCancel" { $Type = 1 }
        "AbortRetryIgnore" { $Type = 2 }
        "YesNoCancel" { $Type = 3 }
        "YesNo" { $Type = 4 }
        "RetryCancel" { $Type = 5 }
        default {} # TODO, make sure $Type is integer, otherwise return 0
    }

    switch($Icon){
        "Critical" { $Icon = 16 }
        "Question" { $Icon = 32 }
        "Exclamation" { $Icon = 48 }
        "Information" { $Icon = 64 }
        default {} # TODO, make sure $Icon is integer, otherwise return 0
    }

    $stringReturns = @{
        "1" = "OK";
        "2" = "Cancel";
        "3" = "Abort";
        "4" = "Retry";
        "5" = "Ignore";
        "6" = "Yes";
        "7" = "No";
    }

    $return = (New-Object -ComObject WScript.Shell).Popup($Text, 0, $Title, $($Type+$Icon))

    if($ReturnText){
        $return = $stringReturns["$return"]
    }

    return $return
}


################################### CUSTOM OBJECTS ###################################
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

########################################## MISC ##########################################
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

######################################### ALIASES #########################################
   #This is for setting aliases, manly to keep backward compatibility

Set-Alias -Name New-Alert -Value New-MessageBox
Set-Alias -Name Use-EasyGUI -Value Initialize-EasyGUI

################################### ICON EXTRACTOR CLASS ###################################
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