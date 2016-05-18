#region Add Assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
#endregion

#region Create Class

Function Create-EphingClass {
    Param (
        $ClassName,
        $ClassHash
    )

    $Class = @"
using System.ComponentModel;
using System.Windows;
public class $ClassName : INotifyPropertyChanged
{

"@
    Foreach ($Key in $ClassHash.Keys) {
        $ClassType = $ClassHash[$Key]
        $Class = $Class + @"
        private $ClassType private$Key;
        public $ClassType $key
        {
            get { return private$Key; }
            set
            {
                private$Key = value;
                NotifyPropertyChanged("$Key");
            }
        }
"@
    }
$Class = $Class + @"

    public event PropertyChangedEventHandler PropertyChanged;
    private void NotifyPropertyChanged(string property)
    {
        if(PropertyChanged != null)
        {
            PropertyChanged(this, new PropertyChangedEventArgs(property));
        }
    }
}
"@
    $null = Add-Type -Language CSharp $Class
}

$ClassHash = @{

}
Create-EphingClass -ClassName 'WindowClass' -ClassHash $ClassHash

#endregion

#region Set up thread
$WindowHashTable = [hashtable]::Synchronized(@{})
$WindowHashTable.Host = $Host
$WindowHashTable.WindowDataContext = New-Object -TypeName WindowClass
$Runspace = [RunspaceFactory]::CreateRunspace()
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
$Runspace.SessionStateProxy.SetVariable("WindowHashTable",$WindowHashTable)
#endregion

$psScript = [Powershell]::Create().AddScript({

[xml]$xaml = @'

'@

$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$Window.DataContext = $WindowHashTable.WindowDataContext

$xaml.SelectNodes("//*[@Name]") | Foreach-Object { Set-Variable -Name (("Window" + "_" + $_.Name)) -Value $Window.FindName($_.Name) }

$Window.ShowDialog() | Out-Null

})

#region Start new thread
$psScript.Runspace = $Runspace
$Handle = $psScript.BeginInvoke()
#endregion

#region Make window not close
while ($StopTheMadness -ne $true) {
    Start-Sleep 1
}
#endregion