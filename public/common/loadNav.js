//------------------------------------------------------------------------------
//  function loadNavBar()
//------------------------------------------------------------------------------
function loadNavBar()
{
	let url = window.location.href;
	let navURL = url.replace( /(http.?:\/\/[^\/]*\/[^\/]*).*/i, "$1/navBar.html");
	fetch( navURL)
       .then(response => response.text())
       .then(data => {
            document.getElementById('navbar').innerHTML = data;
        });

}

//==============================================================================
//  function makeABackup()
//		This function calls the server to make a backup and then provides a
//		download link.
//==============================================================================
function makeABackup()
{
	if ( !("WebSocket" in window))
	{
		alert('This browser does not support WebSockets!');
		return;
	}

	let url = window.location.href;
	let backupURL = url.replace( /(http.?:\/\/[^\/]*\/[^\/]*).*/i, "$1/backup");

	ws = new WebSocket( backupURL );
	ws.onopen = function()
	{
		ws.send( "Backup");
	};

	ws.onmessage = async function (evt)
	{
		var data = evt.data;
		const response = await fetch( "/" + data);
		const blob = await response.blob();

		var anchor = document.createElement('a');
		anchor.href = window.URL.createObjectURL( blob);
		anchor.download = data;
		anchor.click();
		anchor.remove();
		window.location.href = "cleanBackup";


	}
}


window.addEventListener( "pageshow", loadNavBar);


