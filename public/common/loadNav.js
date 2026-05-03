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
			setUpHamburger();
        });


}

//==============================================================================
//  function closeAllSubmenus()
//==============================================================================
function closeAllSubmenus()
{
    document.querySelectorAll('.submenuContent').forEach(sub => sub.classList.remove('show'));
}

//==============================================================================
//  function setUpHamburger()
//==============================================================================
function setUpHamburger()
{
	const menuBtn = document.getElementById('menuToggleButton');
	const mainMenu = document.getElementById('menu');
	const subMenuButtons = document.querySelectorAll('.submenuButton');

	// 1. Toggle Main Drawer
	menuBtn.addEventListener('click', (e) => {
		e.stopPropagation();
		const isOpening = !mainMenu.classList.contains('open');

		menuBtn.classList.toggle('active');
		mainMenu.classList.toggle('open');

		// IF we are closing the menu (by clicking the X), hide submenus too
		if (!isOpening) 
		{
			closeAllSubmenus();
		}
	});

	// 2. Toggle Submenus
	subMenuButtons.forEach(trigger => {
		trigger.addEventListener('click', (e) => {
			e.stopPropagation();
			const targetId = trigger.getAttribute('data-target');
			const targetMenu = document.getElementById(targetId);

			// Close other submenus first
			document.querySelectorAll('.submenuContent').forEach(sub => {
				if (sub !== targetMenu)
				{
					sub.classList.remove('show');
				}
			});

			targetMenu.classList.toggle('show');
		});
	});

	// 3. Click Outside to Close Everything
	document.addEventListener('click', (e) => {
		if (!mainMenu.contains(e.target) && !menuBtn.contains(e.target)) {
			mainMenu.classList.remove('open');
			menuBtn.classList.remove('active');
			closeAllSubmenus();
		}
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


