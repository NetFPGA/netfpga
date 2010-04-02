var isUpdater = false;
var updater = null;
var statsUpdater = null;

function statsToggle() {
	$('stats').toggle();
	var isVisible = $('stats').visible();
	if (isVisible) {
		if (statsUpdater == null) {
			statsUpdater = new Ajax.PeriodicalUpdater('stats', '/stats.html',
				{
					method: 'get',
					frequency: 1,
					decay: 1
				});
		} else {
			statsUpdater.start();
		}
	} else {
		if (statsUpdater != null) {
			statsUpdater.stop();
		}
	}
}

function loadURL(url, refresh) {
	if (!refresh) {
		if (isUpdater) {
			updater.stop();
			updater = null;
			isUpdater = false;
		}

		new Ajax.Request(url, {
			method: 'get',
			onSuccess: function (transport) {
				var ele = parent.content.document.getElementById('main_pre');
				ele.innerHTML = transport.responseText;
			}
		});
	} else {
		if (isUpdater) {
			updater.stop();
			updater = null;
		}

		isUpdater = true;
		updater =  new Ajax.PeriodicalUpdater('null', url, {
			method: 'get',
			frequency: 1,
			decay: 1,
			onSuccess: function (transport) {
				var ele = parent.content.document.getElementById('main_pre');
				ele.innerHTML = transport.responseText;
			}
		});
	}
}

function commandSubmit() {
		if (top.left.isUpdater) {
			top.left.updater.stop();
			top.left.updater = null;
			top.left.isUpdater = false;
		}
		var params = $('command_line').serialize(true);
		new Ajax.Request('/command.html', {
			method: 'get',
			parameters: params,
			onSuccess: function (transport) {
				var ele = top.content.document.getElementById('main_pre');
				ele.innerHTML = transport.responseText;
			}
		});
}