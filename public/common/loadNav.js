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

	ws.onmessage = function (evt)
	{
		var data = evt.data;
		var anchor = document.createElement('a');
		anchor.href = "/" + data;
		anchor.download = data;
		document.body.appendChild( anchor);
		anchor.click();
		document.body.removeChild( anchor);
	}
}


window.addEventListener( "pageshow", loadNavBar);


