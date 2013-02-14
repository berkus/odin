	function active(name)
	{
      document.images[name].src = 'images/'+name+'-h.gif'
	}

	function inactive(name)
	{
      document.images[name].src = 'images/'+name+'.gif'
	}

   var myimages=new Array()
   function preloadimages()
   {
     for (i=0; i<preloadimages.arguments.length; i++)
     {
       myimages[i]=new Image();
       myimages[i].src= "images/" + preloadimages.arguments[i] + ".gif";
     }
   }

   preloadimages( "odin-page-logo", "header-filler",
   "menu_news", "menu_news-h", "menu_meeting", "menu_meeting-h", "menu_team", "menu_team-h", "menu_work", "menu_work-h",
   "menu_download", "menu_download-h", "menu_guides", "menu_guides-h", "menu_browsecvs", "menu_browsecvs-h",
   "menu_milestones", "menu_milestones-h", "menu_gods", "menu_gods-h", "menu_back", "menu_back-h", "menu_apply", "menu_apply-h",
   "odin88x31", "odin88x40", "odin88x40dark", "progress_left", "progress_empty", "progress_done", "progress_right", "small-arrow")
