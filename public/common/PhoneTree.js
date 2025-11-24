

//==============================================================================
//  function multiSelectWithoutCtrl( selector)
//		This function sets an event handler to toggle the selected state of a
//		multiple select option without reseting all other options.  (Like
//		pressing CTRL while selecting an option.)
//==============================================================================
function multiSelectWithoutCtrl( selector)
{
	let options = document.getElementsByClassName( selector);
	for ( const option of options)
	{
		if ( option.getAttribute( "ctrlHandler") != "true")
		{
			option.addEventListener( "mousedown",
				function(e)
				  {
					  if ( !e.shiftKey)
					  {
						  e.preventDefault();
					  }
					  option.parentElement.focus();
					  this.selected = !this.selected;
					  return false;
				  }
				);
			option.setAttribute( "ctrlHandler", true);
		}

	}
}

//==============================================================================
//  function selectAllItems( id)
//		This function selects all entries in the list indicated by the id.
//==============================================================================
function selectAllItems( id)
{
	let list = document.getElementById( id);
	for( let option of list.options)
	{
		option.selected = true;
	}
}

//==============================================================================
//  function unSelectAllItems( id)
//		This function unselects all entries in the members list
//==============================================================================
function unSelectAllItems( id)
{
	let list = document.getElementById( id);
	for( let option of list.options)
	{
		option.selected = false;
	}
}


//==============================================================================
//  function readGroupList()
//		This asyncrhonous function returns a Promise.  On completion, the result
//		is an array of group names.
//==============================================================================
function readGroupList()
{
	return new Promise((resolve, reject) =>
		{
			var ws;
			var url;

			if ( window.location.protocol == 'https:')
			{
				url = 'wss://' + window.location.host + '/phonetree/getGroups';
			}
			else
			{
				url = 'ws://' + window.location.host + '/phonetree/getGroups';
			}
			ws = new WebSocket( url);

			ws.onopen = (event) => 
			{
				ws.send('');
			};

			ws.onerror = (event) =>
			{
				ws.close();
				ws = new WebSocket( url);
				ws.onopen = (event) => 
				{
					ws.send('');
				};
			};

			ws.onmessage = (msg) =>
			{
				let reply = JSON.parse( msg.data);
				resolve( reply);
			};
		}
	);
}

//==============================================================================
//  function readContactList()
//		This asyncrhonous function returns a Promise.  On completion, the result
//		is an array of contact names.
//==============================================================================
function readContactList()
{
	return new Promise((resolve, reject) =>
		{
			var ws;
			var url;

			if ( window.location.protocol == 'https:')
			{
				url = 'wss://' + window.location.host + '/phonetree/getContacts';
			}
			else
			{
				url = 'ws://' + window.location.host + '/phonetree/getContacts';
			}
			ws = new WebSocket( url);

			ws.onopen = (event) => 
			{
				ws.send('');
			};

			ws.onerror = (event) =>
			{
				ws.close();
				ws = new WebSocket( url);
				ws.onopen = (event) => 
				{
					ws.send('');
				};
			};

			ws.onmessage = (msg) =>
			{
				let reply = JSON.parse( msg.data);
				resolve( reply);
			};
		}
	);
}

//==============================================================================
//  function readGroupMemberList( groupName)
//		This asynchronous function returns a Promise.  On completion, the result
//		is an array of members of the named group.
//			( {memberName: <memberName>, id: <idNumber>, isGroup: [0|1]}
//==============================================================================
function readGroupMemberList( groupName)
{
	return new Promise((resolve, reject) =>
		{
			var ws;
			var url;

			if ( window.location.protocol == 'https:')
			{
				url = 'wss://' + window.location.host + '/phonetree/getGroupMembers';
			}
			else
			{
				url = 'ws://' + window.location.host + '/phonetree/getGroupMembers';
			}
			ws = new WebSocket( url);

			ws.onopen = (event) => 
			{
				ws.send( groupName);
			};

			ws.onerror = (event) =>
			{
				ws.close();
				ws = new WebSocket( url);
				ws.onopen = (event) => 
				{
					ws.send( groupName);
				};
			};

			ws.onmessage = (msg) =>
			{
				let reply = JSON.parse( msg.data);
				resolve( reply);
			};
		}
	);
}

//==============================================================================
//  function redrawGroupList( id, redrawFinished, changedCallback)
//  	This function redraws the list of group names in the indicated element.
//  	If changedCallback is provided, an event listener is set on each option
//  	to call that function on change for the option. When the list is
//  	rebuilt, the redrawFinished callback is called (if provided).
//==============================================================================
function redrawGroupList( id, redrawFinished, changedCallback )
{
	let datalist = document.getElementById( id);
 
	//
	//  First clear the list
	//
	while( datalist.options.length > 0)
	{
		datalist.removeChild( datalist.options[0]);
	}

	//
	//  Next, get the current group list
	//
	readGroupList()
		.then( (list) =>
			{
				let datalist = document.getElementById( id);

				list.forEach( (row) =>
					{
						let option = new Option( row[0], row[0]);
						option.className = "multiSel";
						option.setAttribute( "type", "group");
						if ( changedCallback !== undefined)
						{
							option.addEventListener( 'click', () => {changedCallback( option)});
						}
						datalist.appendChild( option);
					});
				if ( redrawFinished !== undefined)
				{
					redrawFinished();
				}

			});

}

