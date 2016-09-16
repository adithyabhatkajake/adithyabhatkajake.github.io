<?php
		$file = fopen("results.txt","a");
		fwrite($file,$_POST["name1"]." ".$_POST["roll1"]." ".$_POST["name2"]." ".$_POST["roll2"]." ".$_POST["link"]."\n");
		fclose($file);
		
?>
