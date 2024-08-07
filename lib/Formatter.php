<?
use function Safe\preg_replace;

class Formatter{
	private static Transliterator $_Transliterator;
	private static Parsedown $_MarkdownParser;

	/**
	 * Remove diacritics from a string, leaving the now-unaccented characters in place.
	 */
	public static function RemoveDiacritics(string $text): string{
		if(!isset(Formatter::$_Transliterator)){
			$transliterator = Transliterator::createFromRules(':: Any-Latin; :: Latin-ASCII; :: NFD; :: [:Nonspacing Mark:] Remove; :: Lower(); :: NFC;', Transliterator::FORWARD);

			if($transliterator === null){
				return $text;
			}
			else{
				Formatter::$_Transliterator = $transliterator;
			}
		}

		$transliteratedText = Formatter::$_Transliterator->transliterate($text);

		if($transliteratedText === false){
			return $text;
		}
		else{
			return $transliteratedText;
		}
	}

	/**
	 * Escape a string so that it's appropriate to use in a URL slug.
	 *
	 * This does the following to the string:
	 *
	 * 1. Removes any diacritics.
	 *
	 * 2. Removes apostrophes.
	 *
	 * 3. Converts the string to lowercase.
	 *
	 * 4. Converts any non-digit, non-letter character to a space.
	 *
	 * 5. Converts any sequence of one or more spaces to a single dash.
	 */
	public static function MakeUrlSafe(string $text): string{
		// Remove accent characters
		$text = Formatter::RemoveDiacritics($text);

		// Remove apostrophes
		$text = preg_replace('/[\'’]/u', '', $text);

		// Trim and convert to lowercase
		$text = mb_strtolower(trim($text));

		// Then convert any non-digit, non-letter character to a space
		$text = preg_replace('/[^0-9a-zA-Z]/ius', ' ', $text);

		// Then convert any instance of one or more space to dash
		$text = preg_replace('/\s+/ius', '-', $text);

		// Finally, trim dashes
		$text = trim($text, '-');

		return $text;
	}

	/**
	 * Escape a string so that it's safe to output directly into an HTML document.
	 */
	public static function EscapeHtml(?string $text): string{
		return htmlspecialchars(trim($text ?? ''), ENT_QUOTES, 'utf-8');
	}

	/**
	 * Escape a strin so that it's safe to output directly into an XML document. Note that this is **not the same** as escaping for HTML. Any query strings in URLs should already be URL-encoded, for example `?foo=bar+baz&x=y`.
	 */
	public static function EscapeXml(?string $text): string{
		return htmlspecialchars(trim($text ?? ''), ENT_QUOTES|ENT_XML1, 'utf-8');
	}

	/**
	 * Convert a string of Markdown into HTML.
	 */
	public static function MarkdownToHtml(?string $text): string{
		if(!isset(Formatter::$_MarkdownParser)){
			Formatter::$_MarkdownParser = new Parsedown();
			Formatter::$_MarkdownParser->setSafeMode(true);
		}

		return Formatter::$_MarkdownParser->text($text);
	}

	/**
	 * Given a number of bytes, return a string containing a human-readable filesize.
	 *
	 * @see https://stackoverflow.com/a/5501447
	 */
	public static function ToFileSize(?int $bytes): string{
		$output = '';

		if($bytes >= 1073741824){
			$output = number_format(round($bytes / 1073741824, 1), 1) . 'G';
		}
		elseif($bytes >= 1048576){
			$output = number_format(round($bytes / 1048576, 1), 1) . 'M';
		}
		elseif($bytes >= 1024){
			$output = number_format($bytes / 1024, 0) . 'KB';
		}
		elseif($bytes > 1){
			$output = $bytes . 'B';
		}
		elseif($bytes == 1){
			$output = $bytes . 'B';
		}
		else{
			$output = '0B';
		}

		return $output;
	}
}
