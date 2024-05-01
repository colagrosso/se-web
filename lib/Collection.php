<?
use function Safe\preg_replace;

class Collection{
	public string $Name;
	public string $UrlName;
	public string $Url;
	public ?int $SequenceNumber = null;
	public ?string $Type = null;

	public static function FromFile(string $name){
		$instance = new Collection();
		$instance->Name = $name;
		$instance->UrlName = Formatter::MakeUrlSafe($instance->Name);
		$instance->Url = '/collections/' . $instance->UrlName;
		return $instance;
	}

	public function GetSortedName(): string{
		return preg_replace('/^(the|and|a|)\s/ius', '', $this->Name);
	}
}
