#import EasyGUI
#. "C:\users\username\Powershell\PS-Reusable\EasyGUI.ps1"
Import-Module EasyGUI


#Get everything setup, this is required before you use any of the features as they often depend on things being loaded
Load-EasyGUI


#Hides the console, this is not required
#When you want to see it again use Show-Console
#Hide-Console


#Threads should be created within a scriptblock like this, this is to prevent it from running as soon as it is created
#They also take a scriptblock as input, thats the code that will run in the thread.
$countThread = {
    New-Thread {

        # This is the code that we want to run inside the thread        
        # $SYNC is used to communicate between threads
        $SYNC.number.Text = ""
        for($i=0; $i -le 60; $i++){
            $SYNC.number.Text = $i
            sleep 1
        }

    }
}



#This thread is never used in the example but shows another way of using threads where you load a ps1 file instead of writing the code in a scriptblock
$myThread = { 
    New-Thread "D:\Program\Powershell\myThread.ps1"
}



#Notice how this thread is not created inside a ScriptBlock, that means that it will start running immediately
New-Thread {
    #This thread doesn't do anything
}



$button = New-Button @{
    Cursor = $CURSOR.Hand # $CURSOR contains all cursor styles
    Location = "15, 10"
    Size = "150, 35"
    Text = "Start counting"
    Add_Click = { &$myThread } #Run the thread when the button is clicked
}



$number = New-Label @{
    Location = "160, 7"
    Size = "150, 35"
    Font = New-Font -Font "Lucidia Console" -Size 28 -Style $FONTSTYLE.Bold # $FONTSTYLE contains all font styles
}
#We want to be able to access this object from all threads so add it to $SYNC like this
$SYNC.number = $number

$form = New-Form @{
    Size = "235, 95"
    Text = "Count to 60" 
    FormBorderStyle = 'FixedDialog'
    MaximizeBox = $false
}
$form.Controls.AddRange(@($button, $SYNC.number))



Show-Form $form



#This makes sure that the process gets killed when closing the window
Stop-Console