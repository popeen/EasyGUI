    # Version: 4 

    function Initialize-EasyGUI{
        #This needs to be called before anything else in EasyGUI is called

        [Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')| Out-Null
        [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")| Out-Null
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
     
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '

        
        #Generates a variable $SYNC that can be accessed from all threads, store your objects there to access them from everywhere
        #Example: In main script $SYNC.TextBox = New-TextBox @{ Text = "Text" }
        #In thread $script:SYNC.TextBox.Text = "New Text"

        $global:SYNC = [Hashtable]::Synchronized(@{})



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
        [Environment]::Exit(1)
    }

    function Show-Form{
        param([System.Windows.Forms.Form]$form, $run)
        if ($PSBoundParameters.ContainsKey('run')){
            [Windows.Forms.Application]::Run($form)
        }else{
            $form.ShowDialog()
        }
    }




    ################################### MULTITHREADING (ish) ###################################
        #Store things in $SYNC (gets automatically created when calling Load-EasyGUI) to be able to access them from inside threads
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
    
    function New-StatusBar{
        param([HashTable]$Property)
        return New-Object System.Windows.Forms.StatusBar -Property $Property
    }
	
    function New-TextBox{
        param([HashTable]$Property)
        return New-Object System.Windows.Forms.TextBox -Property $Property
    }
	
    function New-ToolStripMenuItem{
        param([HashTable]$Property)
        return New-Object System.Windows.Forms.ToolStripMenuItem -Property $Property
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
    

    function New-Font{
        param([String]$Font, [int]$Size, [System.Drawing.FontStyle]$style)
        return New-Object System.Drawing.Font($Font, $Size, $Style)
    }

    function Get-Icon{
        param([String]$File, [int]$IconNumber, [boolean]$LargeIcon = $TRUE)
        return [System.IconExtractor]::Extract($File, $IconNumber, $LargeIcon)
    }

    function New-InputBox{
        #This is using VBScript InputBox, more info about it can be found here https://msdn.microsoft.com/en-us/library/microsoft.visualbasic.interaction.inputbox(v=vs.110).aspx
        param([String]$Title = "", [String]$Text)
        [Microsoft.VisualBasic.Interaction]::InputBox($Text, $Title)
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
        param([String]$Title = "", [String]$Text, [int]$Type = 0)
        return (New-Object -ComObject WScript.Shell).Popup($Text, 0, $Title, $Type)
    }


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